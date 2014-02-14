package Crawl::Bot::Plugin::Commit;
use Moose;
use autodie;
use File::pushd;
extends 'Crawl::Bot::Plugin';

has repo_uri => (
    is      => 'ro',
    isa     => 'Str',
    default => 'git://gitorious.org/crawl/crawl.git',
);

has announce_commits => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has abbrev_cherry_picks => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

# Maximum number of commits to announce from a large batch.  If there
# are exactly announce_limits + 1 new commits, all of them will be
# announced, to avoid a useless "and 1 more commit" message.
has announce_limit => (
    is      => 'rw',
    isa     => 'Int',
    default => 10,
);

has colour_announce => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has colour_query => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has checkout => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $checkout = File::Spec->catdir($self->data_dir, 'crawl-ref');
        mkdir $checkout unless -d $checkout;
        my $dir = pushd($checkout);
        if (!-f 'HEAD') {
            system('git clone --mirror ' . $self->repo_uri . " $checkout");
        }
        $checkout;
    },
);

has heads => (
    traits  => [qw(Hash)],
    isa     => 'HashRef[Str]',
    lazy    => 1,
    handles => {
        has_branch => 'exists',
        head       => 'accessor',
    },
    default => sub {
        my $self = shift;
        my $dir = pushd($self->checkout);
        return { map { $_ => `git rev-parse $_` } $self->branches };
    },
);

my %colour_codes = (
    author => 3,
    author_query => 7,
    committer => 2,
    branch => 7,
    stats => 10,
    url => 13
);

sub make_commit_uri {
    my $self = shift;
    my $commit = shift;
    return "http://s-z.org/neil/git/?p=crawl.git;a=commitdiff;h=$commit";
}

sub make_branch_uri {
    my $self = shift;
    my $branch = shift;
    return "http://s-z.org/neil/git/?p=crawl.git;a=log;h=refs/heads/$branch";
}

sub colour {
    my $self = shift;
    my $context = shift;
    my $type = shift;

    if ($context eq "announce") {
        return "" unless $self->colour_announce;
    } elsif ($context eq "query") {
        return "" unless $self->colour_query;
    }

    if ($type eq "reset") {
        return "\017";
    } elsif ($type eq "colon" or $type eq "rev") {
        return "\002";
    } else {
        my $code = $colour_codes{$type};
        return defined($code) ? sprintf("\003%02d", $code) : "";
    }
}

sub said {
    my $self = shift;
    my ($args) = @_;

    my @keys = (who => $args->{who}, channel => $args->{channel}, "body");

    if ($args->{body} =~ /^\%git(?:\s+(.*))?$/) {
        my $rev = $1;
        $rev = "HEAD" unless $rev;
        my $commit = $self->parse_commit($rev);
        if (defined $commit) {
            my $abbr = substr($commit->{hash}, 0, 12);
            my $pl = ($commit->{nfiles} == 1 ? "" : "s");

            my $rev = $commit->{revname} || "$abbr";
            my $committer = "";
            if ($commit->{committer} ne $commit->{author}) {
                    $committer = " {" . $commit->{committer} . "}";
            }

            $self->say(@keys,
                sprintf(
                    "%s%s%s%s%s%s * %s%s%s:%s %s%s%s %s(%s, %s file%s, %s+ %s-)%s %s%s%s",
                    $self->colour(query => "author_query"), $commit->{author},
                    $self->colour(query => "reset"),
                    $self->colour(query => "committer"), $committer,
                    $self->colour(query => "reset"),
                    $self->colour(query => "rev"), $rev,
                    $self->colour(query => "colon"),
                    $self->colour(query => "reset"),
                    $self->colour(query => "subject"), $commit->{subject},
                    $self->colour(query => "reset"),
                    $self->colour(query => "stats"),
                    $commit->{date}, $commit->{nfiles}, $pl,
                    $commit->{nins}, $commit->{ndel},
                    $self->colour(query => "reset"),
                    $self->colour(query => "url"),
                    $self->make_commit_uri($abbr),
                    $self->colour(query => "reset"),
                )
            );
        } else {
            my $ev = $? >> 8;
            $self->say(@keys, "Could not find commit $rev (git returned $ev)");
        }
    } elsif ($args->{body} =~ /^\%branch\s+(.*)$/) {
        $self->say(@keys, "Branch $1: " . $self->make_branch_uri($1));
    }
}

sub tick {
    my $self = shift;
    my $dir = pushd($self->checkout);
    warn "fetch";
    system('git fetch');
    for my $branch ($self->branches) {
        my $old_head = $self->head($branch) || '';
        warn "rev-parse $branch";
        my $head = `git rev-parse $branch`;
        chomp ($old_head, $head);
        next if $old_head eq $head;

        # Exclude merges from master into other branches.
        my $exclude_master = $branch eq "master" ? "" : "^master";
        my $exclude_old = $old_head ? "^$old_head" : "";
        warn "rev-list $head $exclude_old $exclude_master";
        my @revs = split /\n/, `git rev-list $head $exclude_old $exclude_master`;
        warn "rev-list done";

        if (!$self->has_branch($branch)) {
            my $nrev = scalar @revs;
            my $pl = $nrev == 1 ? "" : "s";
            $self->say_all("New branch created: $branch ($nrev commit$pl)");
        }

        # Announce playable branches in ##crawl, all branches in ##crawl-dev.
        my $say;
        if ($branch =~ /^(?:master|stone_soup-.*)$/) {
            $say = sub {
                $self->say_all(@_)
            }
        } else {
            $say = sub {
                $self->say_main(@_)
            }
        }

        if ($self->announce_commits) {
                my %commits = map { $_, $self->parse_commit($_) } @revs;

                if ($self->abbrev_cherry_picks)
                {
                    my $cherry_picks = @revs;
                    @revs = grep {
                        $commits{$_}->{subject} !~ /\(cherry picked from /
                        && $commits{$_}->{body} !~ /\(cherry picked from /
                    } @revs;
                    $cherry_picks -= @revs;
                    my $pl = $cherry_picks == 1 ? "" : "s";

                    $say->("Cherry-picked $cherry_picks commit$pl into $branch")
                        if $cherry_picks > 0;
                }

                my $count = 0;
                for my $rev (reverse @revs) {
                        # If it's just one more than the announce limit, don't
                        # bother with the message and announce the last commit
                        # anyway.
                        if (++$count > $self->announce_limit and scalar @revs > $count) {
                            $say->("... and " . (scalar @revs - $count + 1) . " more commits");
                            last;
                        }
                        my $commit = $commits{$rev};
                        my $br = $branch eq "master" ? "" : "[$branch] ";

                        my $abbr = substr($commit->{hash}, 0, 12);
                        my $pl = ($commit->{nfiles} == 1 ? "" : "s");

                        my $revname = $commit->{revname} || "$abbr";
                        my $committer = "";
                        if ($commit->{committer} ne $commit->{author}) {
                                $committer = " {" . $commit->{committer} . "}";
                        }

                        $say->(
                            sprintf(
                                "%s%s%s%s%s%s %s%s%s* %s%s%s:%s %s%s%s %s(%s, %s file%s, %s+ %s-)%s %s%s%s",
                                $self->colour(announce => "author"), $commit->{author},
                                $self->colour(announce => "reset"),
                                $self->colour(announce => "committer"), $committer,
                                $self->colour(announce => "reset"),
                                $self->colour(announce => "branch"), $br,
                                $self->colour(announce => "reset"),
                                $self->colour(announce => "rev"), $revname,
                                $self->colour(announce => "colon"),
                                $self->colour(announce => "reset"),
                                $self->colour(announce => "subject"), $commit->{subject},
                                $self->colour(announce => "reset"),
                                $self->colour(announce => "stats"),
                                $commit->{date}, $commit->{nfiles}, $pl,
                                $commit->{nins}, $commit->{ndel},
                                $self->colour(announce => "reset"),
                                $self->colour(announce => "url"),
                                $self->make_commit_uri($abbr),
                                $self->colour(announce => "reset"),
                            )
                        );
                }
        }

        $self->head($branch => $head);
    }
}

sub branches {
    my $self = shift;
    my $dir = pushd($self->checkout);
    return map { s/^[ \*]*//; $_ } split /\n/, `git branch`;
}

sub parse_commit {
    my $self = shift;
    my ($rev) = @_;
    my $dir = pushd($self->checkout);

    CORE::open(F, "-|:encoding(UTF-8)", qw(git log -1 --shortstat --pretty=format:%H%x00%aN%x00%cN%x00%s%x00%b%x00%ar%x00), $rev) or return undef;
    local $/ = undef;
    my $info = <F>;
    CORE::close(F) or return undef;

    my $revname;

    if (CORE::open(F, "-|:encoding(UTF-8)", qw(git describe), $rev)) {
        $revname = <F>;
        $revname =~ s/\n.*//;
        CORE::close(F);
    }

    $info =~ /(.*?)\x00(.*?)\x00(.*?)\x00(.*?)\x00(.*?)\x00(.*?)\x00(.*)/s or return undef;
    my ($hash, $author, $committer, $subject, $body, $date, $stat) = ($1, $2, $3, $4, $5, $6, $7);

    my ($nfiles, $nins, $ndel);
    ($stat =~ /(\d+) files changed/) and $nfiles = $1;
    ($stat =~ /(\d+) insertions/) and $nins = $1;
    ($stat =~ /(\d+) deletions/) and $ndel = $1;
    return {
        hash      => $hash,
        author    => $author,
        committer => $committer,
        subject   => $subject,
        body      => $body,
        date      => $date,
        nfiles    => $nfiles,
        nins      => $nins,
        ndel      => $ndel,
        revname   => $revname,
    };
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

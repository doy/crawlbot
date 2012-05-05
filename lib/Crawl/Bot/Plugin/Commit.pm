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

sub said {
    my $self = shift;
    my ($args) = @_;

    my @keys = (who => $args->{who}, channel => $args->{channel}, "body");

    if ($args->{body} =~ /^%git(?:\s+(.*))?$/) {
        my $rev = $1;
        $rev = "HEAD" unless $rev;
        my $commit = $self->parse_commit($rev);
        if (defined $commit) {
            my $abbr = substr($commit->{hash}, 0, 12);
            my $pl = ($commit->{nfiles} == 1 ? "" : "s");

            $self->say(@keys, "$commit->{author} * r$abbr: $commit->{subject} "
                . "($commit->{date}, $commit->{nfiles} file$pl, "
                . "$commit->{nins}+ $commit->{ndel}-)"
            );
        } else {
            my $ev = $? >> 8;
            $self->say(@keys, "Could not find commit $rev (git returned $ev)");
        }
    }
}

sub tick {
    my $self = shift;
    my $dir = pushd($self->checkout);
    system('git fetch');
    for my $branch ($self->branches) {
        my $old_head = $self->head($branch) || '';
        my $head = `git rev-parse $branch`;
        chomp ($old_head, $head);
        next if $old_head eq $head;

        my @revs = split /\n/, `git rev-list $old_head..$head`;

        if (!$self->has_branch($branch)) {
            my $nrev = scalar @revs;
            $self->say_all("New branch created: $branch ($nrev commits)");
        }

        if ($self->announce_commits) {
                my %commits = map { $_, $self->parse_commit($_) } @revs;

                my $cherry_picks = @revs;
                @revs = grep { $commits{$_}->{subject} !~ /\(cherry picked from /
                        && $commits{$_}->{body}    !~ /\(cherry picked from / } @revs;
                $cherry_picks -= @revs;
                $self->say_all("Cherry-picked $cherry_picks commits into $branch")
                if $cherry_picks > 0;

                for my $rev (@revs) {
                        my $commit = $commits{$rev};
                        my $abbr = substr($rev, 0, 12);
                        my $br = $branch eq "master" ? "" : "[$branch] ";
                        $self->say_all("$commit->{author} $br* $abbr ($commit->{nfiles} changed): $commit->{subject}");
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

    CORE::open(F, "-|", qw(git log -1 --shortstat --pretty=format:%H%x00%aN%x00%s%x00%b%x00%ar%x00), $rev) or return undef;
    local $/ = undef;
    my $info = <F>;
    CORE::close(F) or return undef;

    $info =~ /(.*?)\x00(.*?)\x00(.*?)\x00(.*?)\x00(.*?)\x00(.*)/s or return undef;
    my ($hash, $author, $subject, $body, $date, $stat) = ($1, $2, $3, $4, $5, $6);

    my ($nfiles, $nins, $ndel);
    ($stat =~ /(\d+) files changed/) and $nfiles = $1;
    ($stat =~ /(\d+) insertions/) and $nins = $1;
    ($stat =~ /(\d+) deletions/) and $ndel = $1;
    return {
        hash    => $hash,
        author  => $author,
        subject => $subject,
        body    => $body,
        date    => $date,
        nfiles  => $nfiles,
        nins    => $nins,
        ndel    => $ndel,
    };
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

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

sub tick {
    my $self = shift;
    my $dir = pushd($self->checkout);
    system('git fetch');
    for my $branch ($self->branches) {
        my $old_head = $self->head($branch) || '';
        my $head = `git rev-parse $branch`;
        chomp ($old_head, $head);
        next if $old_head eq $head;

        if (!$self->has_branch($branch)) {
            $self->say_all("New branch created: $branch");
        }

        my @revs = split /\n/, `git rev-list $old_head..$head`;
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
            $self->say_all("$commit->{author} * r$abbr ($commit->{nfiles} changed): $commit->{subject}");
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
    my $info = `git log -1 --pretty=format:%aN%x00%s%x00%b%x00 $rev`;
    $info =~ /(.*?)\x00(.*?)\x00(.*?)\x00(.*)/s;
    my ($author, $subject, $body, $stat) = ($1, $2, $3, $4);
    $stat =~ s/(\d+) files changed/$1/;
    return {
        author  => $author,
        subject => $subject,
        body    => $body,
        nfiles  => $stat,
    };
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

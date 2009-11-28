package Crawl::Bot::Plugin::Mantis;
use Moose;
extends 'Crawl::Bot::Plugin';

use autodie;
use File::Spec;
use XML::RAI;

has rss_feed => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'http://crawl.develz.org/mantis/issues_rss.php',
);

has _cache_file => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'mantis_issue_cache',
);

sub cache_file {
    my $self = shift;
    return File::Spec->catfile($self->data_dir, $self->_cache_file);
}

has issues => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { { } },
    handles => {
        has_issue  => 'exists',
        issues     => 'keys',
        _add_issue => 'set',
    },
);

sub BUILD {
    my $self = shift;
    my $file = $self->cache_file;
    if (-r $file) {
        warn "Updating seen issue list from the cache...";
        open my $fh, '<', $file;
        while (<$fh>) {
            chomp;
            $self->add_issue($_);
            warn "  got issue $_";
        }
    }
    else {
        warn "Updating seen issue list from a fresh copy of the feed...";
        $self->each_issue(sub {
            my $issue = shift;
            my $link = $issue->identifier;
            (my $id = $link) =~ s/.*=(\d+)$/$1/;
            $self->add_issue($id);
            warn "  got issue $id";
        });
        $self->save_cache;
    }
}

sub save_cache {
    my $self = shift;
    warn "Saving cache state to " . $self->cache_file;
    open my $fh, '>', $self->cache_file;
    $fh->print("$_\n") for $self->issues;
}

sub add_issue {
    my $self = shift;
    $self->_add_issue($_[0], 1);
}

sub each_issue {
    my $self = shift;
    my ($code) = @_;
    my $rss = XML::RAI->parse_uri($self->rss_feed);
    for my $issue (@{ $rss->items }) {
        $code->($issue);
    }
}

sub tick {
    my $self = shift;
    warn "Checking for new issues...";
    $self->each_issue(sub {
        my $issue = shift;
        (my $id = $issue->identifier) =~ s/.*=(\d+)$/$1/;
        return if $self->has_issue($id);
        warn "New issue! ($id)";
        (my $title = $issue->title) =~ s/\d+: //;
        my $link = $issue->link;
        (my $user = $issue->creator) =~ s/ <.*?>$//;
        $self->say_all("$title ($link) by $user");
        $self->add_issue($id);
    });
    $self->save_cache;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

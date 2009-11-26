package Crawl::Bot;
use Moose;
use MooseX::NonMoose;
extends 'Bot::BasicBot';

use autodie;
use XML::RAI;

has [qw(username name)] => (
    # don't need (or want) accessors, just want to initialize the hash slot
    # for B::BB to use
    is      => 'bare',
    isa     => 'Str',
    default => sub { shift->nick },
);

has rss_feed => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'http://crawl.develz.org/mantis/issues_rss.php',
);

has cache_file => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'cache',
);

has update_time => (
    is      => 'ro',
    isa     => 'Int',
    default => 300,
);

has issues => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    default => sub {
        my $self = shift;
        my $file = $self->cache_file;
        my $issues = {};
        if (-r $file) {
            warn "Updating seen issue list from the cache...";
            open my $fh, '<', $file;
            while (<$fh>) {
                chomp;
                $issues->{$_} = 1;
                warn "  got issue $_";
            }
        }
        else {
            warn "Updating seen issue list from a fresh copy of the feed...";
            $self->each_issue(sub {
                my $issue = shift;
                my $link = $issue->identifier;
                (my $id = $link) =~ s/.*=(\d+)$/$1/;
                $issues->{$id} = 1;
                warn "  got issue $id";
            });
        }
        return $issues;
    },
    handles => {
        has_issue  => 'exists',
        issues     => 'keys',
        _add_issue => 'set',
    },
);

sub add_issue {
    my $self = shift;
    $self->_add_issue($_[0], 1);
}

sub BUILD {
    my $self = shift;
    $self->save_cache;
}

sub each_issue {
    my $self = shift;
    my ($code) = @_;
    my $rss = XML::RAI->parse_uri($self->rss_feed);
    for my $issue (@{ $rss->items }) {
        $code->($issue);
    }
}

sub save_cache {
    my $self = shift;
    warn "Saving cache state to " . $self->cache_file;
    open my $fh, '>', $self->cache_file;
    $fh->print("$_\n") for $self->issues;
}

sub tick {
    my $self = shift;
    warn "Checking for new issues...";
    $self->each_issue(sub {
        my $issue = shift;
        my $link = $issue->identifier;
        (my $id = $link) =~ s/.*=(\d+)$/$1/;
        return if $self->has_issue($id);
        warn "New issue! ($id)";
        my $message = $issue->title;
        $message =~ s/\d+: //;
        $message = sprintf '%s (%s) by %s',
                           $message, $issue->link, $issue->creator;
        $self->say(
            channel => $_,
            body    => $message,
        ) for $self->channels;
        $self->add_issue($id);
    });
    $self->save_cache;

    return $self->update_time;
}

1;

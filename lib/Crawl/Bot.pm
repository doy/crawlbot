package Crawl::Bot;
use Moose;
use MooseX::NonMoose;
extends 'Bot::BasicBot';

use autodie;
use XML::RAI;

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

has items => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    default => sub {
        my $self = shift;
        my $file = $self->cache_file;
        my $items = {};
        if (-r $file) {
            warn "Updating seen item list from the cache...";
            open my $fh, '<', $file;
            while (<$fh>) {
                chomp;
                $items->{$_} = 1;
                warn "  got item $_";
            }
        }
        else {
            warn "Updating seen item list from a fresh copy of the feed...";
            $self->each_item(sub {
                my $item = shift;
                my $link = $item->identifier;
                (my $id = $link) =~ s/.*=(\d+)$/$1/;
                $items->{$id} = 1;
                warn "  got item $id";
            });
        }
        return $items;
    },
    handles => {
        has_item  => 'exists',
        items     => 'keys',
        _add_item => 'set',
    },
);

sub add_item {
    my $self = shift;
    $self->_add_item($_[0], 1);
}

sub BUILD {
    my $self = shift;
    $self->save_cache;
}

sub each_item {
    my $self = shift;
    my ($code) = @_;
    my $rss = XML::RAI->parse_uri($self->rss_feed);
    for my $item (@{ $rss->items }) {
        $code->($item);
    }
}

sub save_cache {
    my $self = shift;
    warn "Saving cache state to " . $self->cache_file;
    open my $fh, '>', $self->cache_file;
    $fh->print("$_\n") for $self->items;
}

sub tick {
    my $self = shift;
    warn "Checking for new issues...";
    $self->each_item(sub {
        my $item = shift;
        my $link = $item->identifier;
        (my $id = $link) =~ s/.*=(\d+)$/$1/;
        return if $self->has_item($id);
        warn "New issue! ($id)";
        $self->say(channel => '#doytest', body => $item->title . ' (' . $item->link . ')');
        $self->add_item($id);
    });
    $self->save_cache;

    return 60;
}

1;

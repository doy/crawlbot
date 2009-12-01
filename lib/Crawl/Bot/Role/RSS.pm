package Crawl::Bot::Role::RSS;
use Moose::Role;

use autodie;
use File::Spec;
use XML::RAI;

requires 'data_dir', 'rss_item_to_id', 'rss_feed';

has rss_items => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    builder => '_build_rss_items',
    handles => {
        has_rss_item  => 'exists',
        rss_items     => 'keys',
        _add_rss_item => 'set',
    },
);

sub _build_rss_items {
    my $self = shift;
    warn "Loading RSS cache for " . blessed($self);
    my $file = $self->rss_cache_file;
    my %items;
    if (-r $file) {
        open my $fh, '<', $file;
        while (<$fh>) {
            chomp;
            $items{$_} = 1;
        }
    }
    else {
        $self->each_rss_item(sub {
            my $item = shift;
            my $id = $self->rss_item_to_id($item);
            $items{$id} = 1;
        });
    }
    warn "Done loading";
    \%items;
}

sub add_rss_item {
    my $self = shift;
    $self->_add_rss_item($_[0], 1);
}

sub each_rss_item {
    my $self = shift;
    my ($code) = @_;
    my $rss = XML::RAI->parse_uri($self->rss_feed);
    for my $item (@{ $rss->items }) {
        $code->($item);
    }
}

sub save_rss_cache {
    my $self = shift;
    open my $fh, '>', $self->rss_cache_file;
    $fh->print("$_\n") for $self->rss_items;
}

sub rss_cache_file {
    my $self = shift;
    my $class = blessed($self);
    (my $plugin = $class) =~ s/^Crawl::Bot::Plugin:://;
    $plugin = lc($plugin);
    my $file = "${plugin}_rss_cache";
    return File::Spec->catfile($self->data_dir, $file);
}

after BUILDALL => sub {
    my $self = shift;
    $self->save_rss_cache;
};

no Moose::Role;

1;

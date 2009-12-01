package Crawl::Bot::Role::CachedItems;
use Moose::Role;

use autodie;
use File::Spec;

requires 'data_dir', 'current_items', 'item_to_id';

has items => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    builder => '_build_items',
    handles => {
        has_item  => 'exists',
        items     => 'keys',
        _add_item => 'set',
    },
);

sub _build_items {
    my $self = shift;
    warn "Loading item cache for " . blessed($self);
    my $file = $self->item_cache_file;
    my %items;
    if (-r $file) {
        open my $fh, '<', $file;
        while (<$fh>) {
            chomp;
            $items{$_} = 1;
        }
    }
    else {
        $self->each_current_item(sub {
            my $item = shift;
            my $id = $self->item_to_id($item);
            $items{$id} = 1;
        });
    }
    warn "Done loading";
    \%items;
}

sub add_item {
    my $self = shift;
    $self->_add_item($_[0], 1);
}

sub each_current_item {
    my $self = shift;
    my ($code) = @_;
    for my $item ($self->current_items) {
        $code->($item);
    }
}

sub item_cache_file {
    my $self = shift;
    my $class = blessed($self);
    (my $plugin = $class) =~ s/^Crawl::Bot::Plugin:://;
    $plugin = lc($plugin);
    my $file = "${plugin}_item_cache";
    return File::Spec->catfile($self->data_dir, $file);
}

sub save_item_cache {
    my $self = shift;
    open my $fh, '>', $self->item_cache_file;
    $fh->print("$_\n") for $self->items;
}

after BUILDALL => sub {
    my $self = shift;
    $self->save_item_cache;
};

no Moose::Role;

1;

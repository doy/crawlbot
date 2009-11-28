package Crawl::Bot::Plugin;
use Moose;

has bot => (
    is       => 'ro',
    isa      => 'Crawl::Bot',
    required => 1,
    weak_ref => 1,
    handles  => [qw(say_all data_dir)],
);

# not all plugins require a tick method
sub tick { }

__PACKAGE__->meta->make_immutable;
no Moose;

1;

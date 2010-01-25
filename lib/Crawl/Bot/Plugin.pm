package Crawl::Bot::Plugin;
use Moose;

has bot => (
    is       => 'ro',
    isa      => 'Crawl::Bot',
    required => 1,
    weak_ref => 1,
    handles  => [qw(say_all data_dir)],
);

# not all plugins require implementations here
sub tick { }
sub said { }
sub emoted { }
sub chanjoin { }
sub chanpart { }
sub nick_change { }
sub kicked { }
sub topic { }
sub userquit { }
sub sent { }

__PACKAGE__->meta->make_immutable;
no Moose;

1;

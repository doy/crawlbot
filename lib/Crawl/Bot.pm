package Crawl::Bot;
use Moose;
use MooseX::NonMoose;
extends 'Bot::BasicBot';

use File::Path;

has [qw(username name)] => (
    # don't need (or want) accessors, just want to initialize the hash slot
    # for B::BB to use
    is      => 'bare',
    isa     => 'Str',
    default => sub { shift->nick },
);

has data_dir => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'dat',
);

has update_time => (
    is      => 'ro',
    isa     => 'Int',
    default => 300,
);

has mantis => (
    is      => 'ro',
    isa     => 'Crawl::Bot::Mantis',
    lazy    => 1,
    default => sub {
        my $self = shift;
        require Crawl::Bot::Mantis;
        Crawl::Bot::Mantis->new(bot => $self);
    },
);

sub BUILD {
    my $self = shift;
    File::Path::make_path($self->data_dir);
    $self->mantis;
}

before say => sub {
    my $self = shift;
    my %params = @_;
    warn "sending '$params{body}' to $params{channel}";
};

sub tick {
    my $self = shift;
    $self->mantis->tick;
    return $self->update_time;
}

1;

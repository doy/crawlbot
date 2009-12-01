package Crawl::Bot;
use Moose;
use MooseX::NonMoose;
extends 'Bot::BasicBot';

use File::Path;
use Module::Pluggable (
    instantiate => 'new',
    sub_name    => 'create_plugins',
);

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

has plugins => (
    is      => 'ro',
    isa     => 'ArrayRef[Crawl::Bot::Plugin]',
    lazy    => 1,
    default => sub { [__PACKAGE__->create_plugins(bot => shift)] },
);

sub BUILD {
    my $self = shift;
    File::Path::mkpath($self->data_dir);
    $self->plugins;
}

before say => sub {
    my $self = shift;
    my %params = @_;
    warn "sending '$params{body}' to $params{channel}";
};

sub tick {
    my $self = shift;
    warn "Checking for updates...";
    $_->tick for @{ $self->plugins };
    warn "Done";
    return $self->update_time;
}

sub say_all {
    my $self = shift;
    my ($message) = @_;
    $self->say(
        channel => $_,
        body    => $message,
    ) for $self->channels;
}

1;

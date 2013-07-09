package Crawl::Bot::Plugin::Help;
use Moose;
use autodie;
extends 'Crawl::Bot::Plugin';

sub said {
    my $self = shift;
    my ($args) = @_;

    if ($args->{body} =~ /^\%(help|source)/) {
        my $msg = "http://s-z.org/neil/git/cheibriados.git http://s-z.org/neil/git/monster-trunk.git git://gitorious.org/crawl/crawl.git";

        my %keys = (
            who => $args->{who},
            channel => $args->{channel},
            "body" => $msg
        );
        $self->say(%keys);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

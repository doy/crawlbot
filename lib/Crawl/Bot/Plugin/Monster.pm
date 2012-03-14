package Crawl::Bot::Plugin::Monster;
use Moose;

extends 'Crawl::Bot::Plugin';

use autodie;

warn "Loading Plugin::Monster\n";

sub said {
    my $self = shift;
    my ($args) = @_;
    my @keys = (who => $args->{who}, channel => $args->{channel}, "body");

    if ($args->{body} =~ /^%\?\? *(.*)/) {
        my $resp = $self->get_monster_info($1);
        if ($resp) {
            $self->say(@keys, $resp);
        } else {
            $self->say(@keys, "Error calling monster-trunk: $!")
        }
    }
}

sub get_monster_info {
    my $self = shift;
    my $monster = shift;

    CORE::open(F, "-|", "bin/monster-trunk", $monster) or return undef;
    local $/ = undef;
    my $resp = <F>;
    CORE::close(F);

    return $resp;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

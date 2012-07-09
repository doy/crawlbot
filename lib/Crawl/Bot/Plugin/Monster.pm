package Crawl::Bot::Plugin::Monster;
use Moose;

extends 'Crawl::Bot::Plugin';

use autodie;

warn "Loading Plugin::Monster\n";

sub said {
    my $self = shift;
    my ($args) = @_;
    my @keys = (who => $args->{who}, channel => $args->{channel}, "body");

    if ($args->{body} =~ /^%(\?\??) *(.*)/) {
        my $branch = ($1 eq "??") ? "trunk" : "stable";
        my $resp = $self->get_monster_info($2, $branch);
        if ($resp) {
            $self->say(@keys, $resp);
        } else {
            $self->say(@keys, "Error calling monster-$branch: $!")
        }
    }
}

sub get_monster_info {
    my $self = shift;
    my $monster = shift;
    my $branch = shift;

    return "Error: Bad branch $branch\n" unless $branch =~ /^(trunk|stable)$/;

    CORE::open(F, "-|") || do {
        # Collect stderr too
        close STDERR; open STDERR, '>&STDOUT';
        exec "bin/monster-$branch", $monster or die "could not execute monster-$branch: $!";
    };
    binmode F, ":utf8";
    local $/ = undef;
    my $resp = <F>;
    CORE::close(F);

    return $resp;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

package Crawl::Bot::Plugin::Monster;
use Moose;

extends 'Crawl::Bot::Plugin';

use autodie;

warn "Loading Plugin::Monster\n";

sub said {
    my $self = shift;
    my ($args) = @_;
    my @keys = (who => $args->{who}, channel => $args->{channel}, "body");

    if ($args->{body} =~ /^%(\?|0\.\d+|)\? *([^?].*)/) {
        my $branch = ($1 eq "?") ? "trunk" : ($1 || "stable");
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

    return "Error: Bad branch $branch\n" unless $branch =~ /^(trunk|stable|0.\d+)$/;

    CORE::open(F, "-|") || do {
        # Collect stderr too
        close STDERR; open STDERR, '>&STDOUT';
        exec "bin/monster-$branch", $monster or return "Could not execute monster-$branch: $!";
    };
    binmode F, ":utf8";
    local $/ = undef;
    my $resp = <F>;
    CORE::close(F);

    $resp =~ s/^([^\w\s])/_$1/;
    return $resp;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

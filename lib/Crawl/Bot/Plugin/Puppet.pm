package Crawl::Bot::Plugin::Puppet;
use Moose;
use autodie;
extends 'Crawl::Bot::Plugin';

has admin => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    # Make sure these nicks are registered!  Even if they are, there is a
    # time window during which someone could abuse the feature (before
    # being disconnected by nickserv), so we are only using the nick that
    # is usually connected, and not the backups.
    default => sub { [
        '|amethyst', # '\amethyst', 'lamethyst'
    ] }
);

sub said {
    my $self = shift;
    my ($args) = @_;

    my $doit = 0;
    $doit ||= ($_ eq $args->{who}) for @{$self->admin};
    return undef unless $doit;

    if ($args->{body} =~ /^%pup(?:pet)?(a?)(e?)\s+(#\S+\s+)?(\S.*)$/) {
        my ($all, $emote, $namedchan, $msg) = ($1, $2, $3, $4);
        my @chans = $self->bot->channels;

        for my $chan ($namedchan || @chans[0 .. ($all ? $#chans : 0)]) {
            my %keys = (channel => $chan, body => $msg);
            if ($emote) {
                $self->emote(%keys)
            } else {
                $self->say(%keys);
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

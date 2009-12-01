package Crawl::Bot::Plugin::Wiki;
use Moose;
extends 'Crawl::Bot::Plugin';

use XML::RPC;

has xmlrpc_location => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'http://crawl.develz.org/wiki/lib/exe/xmlrpc.php',
);

has wiki_base => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'http://crawl.develz.org/wiki/doku.php?id=',
);

has last_checked => (
    is  => 'rw',
    isa => 'Int',
);

sub tick {
    my $self = shift;
    my $last_checked = $self->last_checked;
    $self->last_checked(time);
    return unless $last_checked;

    my $xmlrpc = XML::RPC->new($self->xmlrpc_location);
    warn "Getting recent wiki changes...";
    my $changes = $xmlrpc->call('wiki.getRecentChanges', $last_checked);
    # ->call returns a hashref with error info on failure
    return unless ref($changes) eq 'ARRAY';
    for my $change (@$changes) {
        warn "Page $change->{name} changed";
        my $history = $xmlrpc->call('wiki.getPageVersions', $change->{name}, 0);
        next if @$history;
        warn "Page $change->{name} is new!";
        my $name = $change->{name};
        my $page = $xmlrpc->call('wiki.getPage', $change->{name});
        if ($page =~ /(===?=?=?=?) (.*) \1/) {
            $name = $2;
        }
        $self->say_all("$change->{author} created page $name at "
                     . $self->wiki_base . "$change->{name}");
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

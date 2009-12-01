package Crawl::Bot::Role::RSS;
use Moose::Role;

use XML::RAI;

with 'Crawl::Bot::Role::CachedItems';

requires 'rss_feed';

sub current_items {
    my $self = shift;
    my $rss = XML::RAI->parse_uri($self->rss_feed);
    return @{ $rss->items };
}

no Moose::Role;

1;

package Crawl::Bot::Role::RSS;
use Moose::Role;

use XML::RAI;

with 'Crawl::Bot::Role::CachedItems';

requires 'rss_feed';

sub current_items {
    my $self = shift;
    my $rss = XML::RAI->parse_uri($self->rss_feed);
    # after the XML::RAI object goes out of scope, the item objects become
    # worthless. how dumb. capture the relevant data in some hashrefs instead.
    return map {
        my $item = $_;
        +{
            map { $_ => $item->$_ }
                qw(identifier title link creator)
         }
    } @{ $rss->items };
}

no Moose::Role;

1;

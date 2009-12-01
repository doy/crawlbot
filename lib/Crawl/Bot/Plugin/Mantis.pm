package Crawl::Bot::Plugin::Mantis;
use Moose;
extends 'Crawl::Bot::Plugin';

with 'Crawl::Bot::Role::RSS';

sub rss_feed { 'http://crawl.develz.org/mantis/issues_rss.php' }

sub item_to_id {
    my $self = shift;
    my ($item) = @_;
    my $link = $item->identifier;
    (my $id = $link) =~ s/.*=(\d+)$/$1/;
    return $id;
}

sub tick {
    my $self = shift;
    $self->each_current_item(sub {
        my $item = shift;
        my $id = $self->item_to_id($item);
        return if $self->has_item($id);
        warn "New issue! ($id)";
        (my $title = $item->title) =~ s/\d+: //;
        my $link = $item->link;
        (my $user = $item->creator) =~ s/ <.*?>$//;
        $self->say_all("$title ($link) by $user");
        $self->add_item($id);
    });
    $self->save_item_cache;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

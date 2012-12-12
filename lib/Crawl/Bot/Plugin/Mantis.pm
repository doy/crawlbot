package Crawl::Bot::Plugin::Mantis;
use Moose;
extends 'Crawl::Bot::Plugin';

with 'Crawl::Bot::Role::RSS';

has enabled => (
    is  => 'ro',
    isa => 'Bool',
    default => 1
);

sub rss_feed { 'https://crawl.develz.org/mantis/issues_rss.php' }

sub item_to_id {
    my $self = shift;
    my ($item) = @_;
    my $link = $item->{identifier};
    (my $id = $link) =~ s/.*=(\d+)$/$1/;
    return $id;
}

sub said {
    my $self = shift;
    my ($args) = @_;
    
    my @keys = (who => $args->{who}, channel => $args->{channel}, "body");

    if ($args->{body} =~ /^%bug (\d+)$/) {
        $self->say(@keys, "https://crawl.develz.org/mantis/view.php?id=$1");
    }
}

sub tick {
    my $self = shift;
    return unless $self->enabled;
    $self->each_current_item(sub {
        my $item = shift;
        my $id = $self->item_to_id($item);
        return if $self->has_item($id);
        warn "New issue! ($id)";
        (my $title = $item->{title}) =~ s/\d+: //;
        my $link = $item->{link};
        (my $user = $item->{creator}) =~ s/ <.*?>$//;
        $self->say_all("$title ($link) by $user");
        $self->add_item($id);
    });
    $self->save_item_cache;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

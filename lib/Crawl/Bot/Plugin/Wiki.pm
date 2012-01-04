package Crawl::Bot::Plugin::Wiki;
use Moose;
extends 'Crawl::Bot::Plugin';

use LWP::UserAgent;
use XML::RPC;
use Try::Tiny;

has xmlrpc_location => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'https://crawl.develz.org/wiki/lib/exe/xmlrpc.php',
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

sub login_file_name {
    my $self = shift;

    return File::Spec->catfile($self->data_dir, 'wiki_login');
}

sub login_wiki {
    my $self = shift;
    my $xmlrpc = shift;
    my ($user, $pass);

    local $_;
    open my $lf, "<", $self->login_file_name
        or die "could not open wiki_login file: $!";

    while (<$lf>) {
        chomp;
        /^\s*user\s*=\s*(.*?)\s*$/ and $user = $1;
        /^\s*password\s*=\s*(.*?)\s*$/ and $pass = $1;
    }

    die "no login info for wiki" unless defined $user and defined $pass;

    warn "logging in to wiki";
    $xmlrpc->call('dokuwiki.login', $user, $pass);
    return;
}

sub tick {
    local $_;
    my $self = shift;
    my $last_checked = $self->last_checked;
    $self->last_checked(time);
    return unless $last_checked;

    # Make sure we (temporarily) save cookies, since the login method sets
    # cookies that the other methods will need.
    my $xmlrpc = XML::RPC->new(
        $self->xmlrpc_location,
        lwp_useragent => LWP::UserAgent->new(cookie_jar => {}),
    );

    try { $self->login_wiki($xmlrpc); } catch { warn $_; return undef; };

    my $changes = try {
        $xmlrpc->call('wiki.getRecentChanges', $last_checked)
    } catch { warn $_ };

    # ->call returns a hashref with error info on failure
    return unless ref($changes) eq 'ARRAY';
    for my $change (@$changes) {
        warn "Page $change->{name} changed";
        my $history = try { $xmlrpc->call('wiki.getPageVersions', $change->{name}, 0) } catch { warn $_ };
        next if !defined($history) || @$history;
        warn "Page $change->{name} is new!";
        my $name = $change->{name};
        my $page = try { $xmlrpc->call('wiki.getPage', $change->{name}) } catch { warn $_ };
        next unless $page;
        if ($page =~ /(===?=?=?=?) (.*) \1/) {
            $name = $2;
        }
        $self->say_all("$change->{author} created page $name at "
                     . $self->wiki_base . "$change->{name}");
    }
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

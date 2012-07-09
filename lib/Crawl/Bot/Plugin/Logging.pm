package Crawl::Bot::Plugin::Logging;
use Moose;
extends 'Crawl::Bot::Plugin';

use autodie;

# XXX: only supports one channel at the moment
# XXX: should strip out mirc color codes from the logs

has date => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    clearer => 'clear_date',
    builder => '_build_date',
);

sub _build_date {
    my ($year, $month, $day) = (localtime)[5, 4, 3];
    $year += 1900;
    $month++;
    return sprintf '%04d%02d%02d', $year, $month, $day;
}

has logfile => (
    is      => 'ro',
    isa     => 'FileHandle',
    lazy    => 1,
    clearer => 'clear_logfile',
    default => sub {
        my $self = shift;
        my $filepath = File::Spec->catfile($self->logfilepath, ($self->bot->channels)[0] . '-' . $self->date . '.log');
        open my $fh, '>>', $filepath;
        $fh->autoflush(1);
        return $fh;
    }
);

has logfilepath => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $path = File::Spec->catdir($self->data_dir, 'log');
        mkdir $path unless -d $path;
        return $path;
    },
);

before logfile => sub {
    my $self = shift;
    if ($self->date ne $self->_build_date) {
        $self->clear_date;
        $self->clear_logfile;
    }
};

sub log_message {
    my $self = shift;
    my ($message) = @_;

    my $timestamp = sprintf '%02d:%02d:%02d', (localtime)[2, 1, 0];
    $self->logfile->print("$timestamp $message\n");
}

sub said {
    my $self = shift;
    my ($args) = @_;

    # Only log the first channel
    if ($args->{channel} eq $self->bot->{channels}[0]) {
        $self->log_message("<$args->{who}> $args->{body}");
    } elsif ($args->{channel} ne "msg"
            and $args->{who} =~ /^(?:Gretell|Henzell|\|amethyst)$/
            and $args->{body} =~ /(\S+) .*became the Champion of Cheibriados/)
    {
        $self->say(
            channel => $args->{channel},
            body => "Did I ever mention that $1 is one of my favourite people?"
        );
    }

    return;
}

sub emoted {
    my $self = shift;
    my ($args) = @_;

    if ($args->{channel} eq $self->bot->{channels}[0]) {
        $self->log_message("* $args->{who} $args->{body}");
    }
    return;
}

sub chanjoin {
    my $self = shift;
    my ($args) = @_;

    if ($args->{channel} eq $self->bot->{channels}[0]) {
        $self->log_message("-!- $args->{who} has joined $args->{channel}");
    }
    return;
}

sub chanpart {
    my $self = shift;
    my ($args) = @_;

    if ($args->{channel} eq $self->bot->{channels}[0]) {
        $self->log_message("-!- $args->{who} has left $args->{channel}");
    }
    return;
}

sub nick_change {
    my $self = shift;
    # bleh... uses different arg format
    my ($old, $new) = @_;

    # I guess we get nick changes everywhere *sigh*
    $self->log_message("-!- $old is now known as $new");
    return;
}

sub kicked {
    my $self = shift;
    my ($args) = @_;

    if ($args->{channel} eq $self->bot->{channels}[0]) {
        $self->log_message("-!- $args->{kicked} was kicked from $args->{channel} by $args->{who} [$args->{reason}]");
    }
    return;
}

sub topic {
    my $self = shift;
    my ($args) = @_;

    # Might as well log this for ##crawl as well.
    if (defined($args->{who})) {
        $self->log_message("-!- $args->{who} changed the topic of $args->{channel} to: $args->{topic}");
    }
    else {
        $self->log_message("-!- The topic of $args->{channel} is: $args->{topic}");
    }
    return;
}

sub userquit {
    my $self = shift;
    my ($args) = @_;

    $self->log_message("-!- $args->{who} has quit [$args->{body}]");
    return;
}

sub sent {
    my $self = shift;
    my ($args) = @_;

    if ($args->{channel} eq $self->bot->{channels}[0]) {
        $self->log_message("<$args->{who}> $args->{body}");
    }
    return;
}

1;

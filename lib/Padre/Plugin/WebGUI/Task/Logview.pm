package Padre::Plugin::WebGUI::Task::Logview;

use strict;
use warnings;

use base 'Padre::Task';

our $LOGLINE_EVENT : shared = Wx::NewEventType();

# Prepare the task - run in the main thread before being handed
# off to a worker (background) thread. The Wx GUI can be
# polled for information here.
sub prepare {
    my $self = shift;

    Wx::Event::EVT_COMMAND( Padre->ide->wx->main, -1, $LOGLINE_EVENT, \&on_log_line );
    return 1;
}

# Event called when new log lines found
sub on_log_line {
    my ( $main, $event ) = @_;
    @_ = ();    # hack to avoid "Scalars leaked"

    my $data = $event->GetData();
    $main->{webgui}->logview->AppendText($data);
}

# Run the task - must not touch the GUI, except through Wx events.
sub run {
    my $self = shift;

    my $name = "/data/wre/var/logs/modproxy.error.log";
    $self->post_event( $LOGLINE_EVENT, "Opening $name\n" );

    require File::Tail;
    my $file = File::Tail->new( name => $name, maxinterval => 0.2 );

    my $max = 5;
    my $start = time;
    while ( defined( my $line = $file->read ) && time - $start < $max ) {
        $self->post_event( $LOGLINE_EVENT, $line );
    }
    $self->post_event( $LOGLINE_EVENT, "Task finished\n" );
    return 1;
}

# This is run in the main thread after the task is done.
# It can update the GUI and do cleanup.
# You don't have to implement this if you don't need it.
#sub finish {
#      my $self = shift;
#      my $main = shift;
#      # cleanup!
#      return 1;
#}

1;

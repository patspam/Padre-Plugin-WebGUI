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

    chomp(my $data = $event->GetData());
    $main->{webgui}->logview->AppendText("$data\n");
}

# Run the task - must not touch the GUI, except through Wx events.
sub run {
    my $self = shift;
    
    require File::Tail;
    my $maxinterval = $self->{maxinterval} || 0.1;
    
    my $ctrl = $self->{ctrl};
    $self->post_event( $LOGLINE_EVENT, "DEBUG: Using $ctrl as control file" );
    
    my @files;
    push( @files, File::Tail->new( name => $ctrl, maxinterval => $maxinterval ) );
    
    for my $file (@{$self->{files}}) {
        if (!-e $file) {
            $self->post_event( $LOGLINE_EVENT, "File does not exist: $file, skipping" );
            next;
        }
        push( @files, File::Tail->new( name => $file, maxinterval => $maxinterval ) );
        $self->post_event( $LOGLINE_EVENT, "DEBUG: Watching file: $file" );
    }

    while (1) {
        my ( $nfound, $timeleft, @pending ) = File::Tail::select( undef, undef, undef, undef, @files );
        unless ($nfound) {
            # perhaps we should 'yield' here?
        }
        else {
            for my $p (@pending) {
                my $filename = $p->{input};
                chomp(my $line = $p->read);
                if ($filename eq $ctrl) {
                    if ($line eq 'exit') {
                        $self->post_event( $LOGLINE_EVENT, "Exiting" );
                        return 1;
                    } elsif ($line eq 'status') {
                        $self->post_event( $LOGLINE_EVENT, "Watching file: $_->{input}" ) for @files;
                    } else {
                        $self->post_event( $LOGLINE_EVENT, "Unknown command: $line" );
                    }
                } else {
                    $self->post_event( $LOGLINE_EVENT, "$filename (" . localtime(time) . ") $line" );
                }
            }
        }
    }
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

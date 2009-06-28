package Padre::Plugin::WebGUI::Task::Logview;

use strict;
use warnings;
use base 'Padre::Task';

our $NEWLINE_EVENT : shared = Wx::NewEventType();

# Prepare the task - run in the main thread before being handed
# off to a worker (background) thread. The Wx GUI can be
# polled for information here.
sub prepare {
    my $self = shift;

    # Pluck out the logview object prior to serialisation
    my $logview = $self->{logview};
    delete $self->{logview};
    
    # Event called when new log lines found
    my $callback = sub {
        my ( $main, $event ) = @_;
        @_ = ();    # hack to avoid "Scalars leaked"

        chomp(my $data = $event->GetData());
        $logview->AppendText("$data\n");
    };
    Wx::Event::EVT_COMMAND( Padre->ide->wx->main, -1, $NEWLINE_EVENT, $callback );
    
    return 1;
}

# Run the task - must not touch the GUI, except through Wx events.
sub run {
    my $self = shift;
    
    require File::Tail;
    my $maxinterval = $self->{maxinterval} || 0.1;
    
    my $ctrl_filename = $self->{ctrl_filename};
    $self->post_event( $NEWLINE_EVENT, "DEBUG: Using $ctrl_filename as control file" );
    
    my @files;
    push( @files, File::Tail->new( name => $ctrl_filename, maxinterval => $maxinterval ) );
    
    for my $file (@{$self->{files}}) {
        if (!-e $file) {
            $self->post_event( $NEWLINE_EVENT, "File does not exist: $file, skipping" );
            next;
        }
        push( @files, File::Tail->new( name => $file, maxinterval => $maxinterval ) );
        $self->post_event( $NEWLINE_EVENT, "DEBUG: Watching file: $file" );
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
                if ($filename eq $ctrl_filename) {
                    if ($line eq 'exit') {
                        $self->post_event( $NEWLINE_EVENT, "Exiting" );
                        return 1;
                    } elsif ($line eq 'status') {
                        $self->post_event( $NEWLINE_EVENT, "Watching file: $_->{input}" ) for @files;
                    } else {
                        $self->post_event( $NEWLINE_EVENT, "Unknown command: $line" );
                    }
                } else {
                    $self->post_event( $NEWLINE_EVENT, "$filename (" . localtime(time) . ") $line" );
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

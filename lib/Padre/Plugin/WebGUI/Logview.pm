package Padre::Plugin::WebGUI::Logview;

use strict;
use warnings;
use Params::Util qw{_INSTANCE};
use Padre::Wx ();
use base 'Padre::Wx::Output';

# generate fast accessors
use Class::XSAccessor 
    getters => {
        ctrl => 'ctrl',
    };
    
sub gettext_label {
	Wx::gettext('WebGUI Log');
}

sub new {
    my $class = shift;
	my $main  = shift;

	# Create the underlying object
	my $self = $class->SUPER::new($main);
    
    # Start by setting up control file
    require File::Temp;
    my $ctrl = File::Temp->new;
    
    # Re-open in >> mode..
    open $ctrl, '>>', $ctrl;
    $self->{ctrl} = $ctrl;
    
    Padre::Util::debug("Created control file: $ctrl");
    
    return $self;
}

sub cmd {
    my $self = shift;
    chomp(my $cmd = shift);
    my $ctrl = $self->ctrl;
    print $ctrl "$cmd\n" if $ctrl;
}

sub start {
    my $self = shift;
    my $opts = shift;
    
    my $files = $opts->{files} or Padre::Util::debug("No files specified");
    
    require Padre::Plugin::WebGUI::Task::Logview;
    my $task = Padre::Plugin::WebGUI::Task::Logview->new( ctrl => $self->ctrl->filename, files => $files );
    $task->schedule; # hand off to the task manager
}

sub stop {
    my $self = shift;
    $self->cmd('exit');
}

#
######################################################################
## Timer Control
#
#my $ID_TIMER = 12345;
#sub start {
#	my $self = shift;
#
#	Padre::Util::debug('starting logview timer');
#	
#	if (!$self->{timer}) {
#	    Padre::Util::debug('Creating new timer');
#		$self->{timer} = Wx::Timer->new(
#			$self,
#			$ID_TIMER
#		);
#		Wx::Event::EVT_TIMER(
#			$self,
#			$ID_TIMER,
#			sub {
#				$self->on_timer( $_[1], $_[2] );
#			},
#		);
#	}
#	
#	if ( $self->{timer}->IsRunning ) {
#		$self->{timer}->Stop;
#	}
#	$self->{timer}->Start( 2000, 1 );
#
#	return;
#}
#
#sub stop {
#	my $self = shift;
#
#	# Stop the timer
#	if ($self->{timer}) {
#		$self->{timer}->Stop;
#	}
#}
#
#sub on_timer {
#	my $self   = shift;
#	my $event  = shift;
#	Padre::Util::debug('on_timer');
#	$self->check_for_updates;
#	
##	my $force  = shift;
##	my $editor = $self->main->current->editor or return;
##
##	my $document = $editor->{Document};
##	unless ( $document and $document->can('check_syntax') ) {
##		$self->clear;
##		return;
##	}
##
##	my $pre_exec_result = $document->check_syntax_in_background( force => $force );
##
##	# In case we have created a new and still completely empty doc we
##	# need to clean up the message list
##	if ( ref $pre_exec_result eq 'ARRAY' && !@{$pre_exec_result} ) {
##		$self->clear;
##	}
##
##	if ( defined $event ) {
##		$event->Skip(0);
##	}
#
#	return;
#}

1;
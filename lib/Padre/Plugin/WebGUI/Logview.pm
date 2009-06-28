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

sub cmd {
    my $self = shift;
    chomp(my $cmd = shift);
    my $ctrl = $self->ctrl;
    print $ctrl "$cmd\n" if $ctrl;
}

sub start {
    my $self = shift;
    my $opts = shift;
    
    # Start by setting up control file
    require File::Temp;
    my $ctrl = File::Temp->new;
    
    # Re-open in >> mode..
    open $ctrl, '>>', $ctrl;
    $self->{ctrl} = $ctrl;
    
    Padre::Util::debug("Created control file: $ctrl");
    
    my $files = $opts->{files} or Padre::Util::debug("No files specified");
    
    require Padre::Plugin::WebGUI::Task::Logview;
    my $task = Padre::Plugin::WebGUI::Task::Logview->new(
        ctrl_filename => $self->ctrl->filename, 
        files => $files,
        logview => $self,
    );
    $task->schedule; # hand off to the task manager
}

sub stop {
    my $self = shift;
    $self->cmd('exit');
}

1;
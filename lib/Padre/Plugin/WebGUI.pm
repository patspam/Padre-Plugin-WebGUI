package Padre::Plugin::WebGUI;

use strict;
use warnings;
use base 'Padre::Plugin';
use Padre::Util ('_T');
use Readonly;

=head1 NAME

Padre::Plugin::WebGUI - Developer tools for WebGUI

=head1 VERSION

Version 0.01_02

=cut

our $VERSION = '0.01_02';

=head1 SYNOPSIS

cpan install Padre::Plugin::WebGUI;

Then use it via L<Padre>, The Perl IDE.

=head1 DESCRIPTION

This plugin adds a "WebGUI" item to the Padre plugin menu, with a bunch of WebGUI-oriented features.

=cut

# generate fast accessors
use Class::XSAccessor getters => {
    wgd => 'wgd',
    log => 'log',
};

my $logfiles = [
    '/data/wre/var/logs/modproxy.error.log', '/data/wre/var/logs/modperl.error.log',
    '/data/wre/var/logs/modrewrite.log',     '/data/wre/var/logs/mylog.log',
    '/data/wre/var/logs/webgui.log',
];

# static field to contain reference to current plugin configuration
my $config;

sub plugin_config {
    return $config;
}

# The plugin name to show in the Plugin Manager and menus
sub plugin_name {
    return _T("WebGUI");
}

# Declare the Padre interfaces this plugin uses
sub padre_interfaces {
    'Padre::Plugin' => 0.29,
        ;
}

# Register the document types that we want to handle
sub registered_documents {      
    'text/x-webgui-asset' => 'Padre::Document::WebGUI::Asset',
}

# called when the plugin is enabled
sub plugin_enable {
    my $self = shift;

    # Read the plugin configuration, and create it if it is not there
    $config = $self->config_read;
    if ( !$config ) {

        # no configuration, let us write some defaults
        $config = {
            WEBGUI_ROOT   => '/data/WebGUI',
            WEBGUI_CONFIG => 'dev.localhost.localdomain.conf',
        };
        $self->config_write($config);
    }

    use Padre::Log;
    my $log = Padre::Log->new( level => 'debug' );
    $self->{log} = $log;
    $self->log->debug("Logged initialised");

    my $wgd = eval {
        require WGDev;
        $self->log->debug(
            "Loading WGDev using WEBGUI_ROOT: $config->{WEBGUI_ROOT} and WEBGUI_CONFIG: $config->{WEBGUI_CONFIG}");
        WGDev->new( $config->{WEBGUI_ROOT}, $config->{WEBGUI_CONFIG} );
    };

    if ($@) {
        $self->log->error("The following error occurred when loading WGDev:\n\n $@");
        $self->main->error("The following error occurred when loading WGDev:\n\n $@");
        return;
    }

    if ( !$wgd ) {
        $self->log->error('Unable to instantiate wgd');
        $self->main->error('Unable to instantiate wgd');
        return;
    }

    $self->{wgd} = $wgd;
    
#    my $handler = Wx::Event::EVT_MENU(
#		$self->main,
#		$self->main->menu->file->{save}, 
#		sub {
#		    my ($main, $event) = @_;
#		    $self->main->error("This is where we will add the wgd save handler");
#            $event->Skip; # keep on processing event handlers
#		}, 
#	);

    return 1;
}

sub session {
    my $self = shift;

    my $session = eval { $self->wgd->session };
    if ($@) {
        $self->log->warn("Unable to get wgd session: $@");
        return;
    }
    return $session;
}

sub ping {
    my $self = shift;
    if ( !$self->session ) {
        $self->main->error(<<END_ERROR);
Oops, I was unable to connect to your WebGUI site.
Please check that your server is running, and that 
the following details are correct:

 WEBGUI_ROOT:\t $config->{WEBGUI_ROOT  }
 WEBGUI_CONFIG:\t $config->{WEBGUI_CONFIG}
END_ERROR
        return;
    }
    return 1;
}

# called when the plugin is disabled/reloaded
sub plugin_disable {
    my $self = shift;
    my $main = $self->main;
    if ( my $asset_tree = $self->{asset_tree} ) {
        $main->right->hide($asset_tree);
        delete $self->{asset_tree};
    }
    if ( my $logview = $self->{logview} ) {
        $logview->stop;
        $main->bottom->hide($logview);
        delete $self->{logview};
    }
    $main->show_output(0);

    # Unload all private classese here, so that they can be reloaded
    require Class::Unload;
    Class::Unload->unload('Padre::Plugin::WebGUI::Task::Logview');
    Class::Unload->unload('Padre::Plugin::WebGUI::Logview');
    Class::Unload->unload('Padre::Plugin::WebGUI::Assets');
    Class::Unload->unload('Padre::Plugin::WebGUI::Preferences');
    Class::Unload->unload('Padre::Document::WebGUI::Asset');
}

sub menu_plugins {
    my $self = shift;
    my $main = shift;

    # Create a simple menu with a single About entry
    $self->{menu} = Wx::Menu->new;

    # Reload
    Wx::Event::EVT_MENU(
        $main,
        $self->{menu}->Append( -1, _T("Reload WebGUI Plugin\tCtrl+Shift+R"), ),
        sub { $main->ide->plugin_manager->reload_current_plugin },
    );

    $self->{menu}->AppendSeparator;

    # WGDev Commands
    my $wgd_submenu = Wx::Menu->new;
    for my $cmd ( $self->wgd_commands ) {
        Wx::Event::EVT_MENU( $main, $wgd_submenu->Append( -1, $cmd ), sub { $self->wgd_cmd($cmd) }, );
    }
    $self->{menu}->Append( -1, 'wgd', $wgd_submenu );

    $self->{menu}->AppendSeparator;

    # WRE Services
    my $wreservice = 'gksudo -- /data/wre/sbin/wreservice.pl';
    my $services   = Wx::Menu->new;
    for my $service (qw(all mysql modperl modproxy spectre)) {
        my $submenu = Wx::Menu->new;
        for my $cmd (qw(start stop restart ping)) {
            Wx::Event::EVT_MENU(
                $main,
                $submenu->Append( -1, _T("\u$cmd \u$service"), ),
                sub { $main->run_command(qq($wreservice --$cmd $service)) },
            );
        }
        $services->Append( -1, "\u$service", $submenu );
    }
    $self->{menu}->Append( -1, _T("WRE Services"), $services );

    $self->{menu}->AppendSeparator;

    # Asset Tree
    $self->{asset_tree_toggle} = $self->{menu}->AppendCheckItem( -1, _T("Show Asset Tree"), );
    Wx::Event::EVT_MENU( $main, $self->{asset_tree_toggle}, sub { $self->toggle_asset_tree } );
    
    # Turn on Asset Tree
    $self->{asset_tree_toggle}->Check(1);
    $self->toggle_asset_tree;

    # Logview
    $self->{logview_toggle} = $self->{menu}->AppendCheckItem( -1, _T("Logview"), );
    Wx::Event::EVT_MENU( $main, $self->{logview_toggle}, sub { $self->toggle_logview } );
    $self->{logview_toggle}->Check(0);

    #	$self->{logview_toggle}->Check($config->{logview_toggle} ? 1 : 0);

    # Online Resources
    my $resources_submenu = Wx::Menu->new;
    my %resources         = $self->online_resources;
    while ( my ( $name, $resource ) = each %resources ) {
        Wx::Event::EVT_MENU( $main, $resources_submenu->Append( -1, $name ), $resource, );
    }
    $self->{menu}->Append( -1, _T("Online Resources"), $resources_submenu );

    # About
    Wx::Event::EVT_MENU( $main, $self->{menu}->Append( -1, _T("About"), ), sub { $self->show_about }, );
    
    # Push
    # Wx::Event::EVT_MENU( $main, $self->{menu}->Append( -1, _T("Push\tCtrl+S"), ), sub { $self->push }, );

    # Return our plugin with its label
    return ( $self->plugin_name => $self->{menu} );
}

sub online_resources {
    my %RESOURCES = (
        'Bug Tracker' => sub {
            Padre::Wx::launch_browser('http://webgui.org/bugs');
        },
        'Community Live Support' => sub {
            Padre::Wx::launch_irc( 'irc.freenode.org' => 'webgui' );
        },
        'GitHub - WebGUI' => sub {
            Padre::Wx::launch_browser('http://github.com/plainblack/webgui');
        },
        'GitHub - WGDev' => sub {
            Padre::Wx::launch_browser('http://github.com/haarg/wgdev');
        },
        'Planet WebGUI' => sub {
            Padre::Wx::launch_browser('http://patspam.com/planetwebgui');
        },
        'RFE Tracker' => sub {
            Padre::Wx::launch_browser('http://webgui.org/rfe');
        },
        'Stats' => sub {
            Padre::Wx::launch_browser('http://webgui.org/webgui-stats');
        },
        'WebGUI.org' => sub {
            Padre::Wx::launch_browser('http://webgui.org');
        },
        'Wiki' => sub {
            Padre::Wx::launch_browser('http://webgui.org/community-wiki');
        },
    );
    return map { $_ => $RESOURCES{$_} } sort { $a cmp $b } keys %RESOURCES;
}

sub show_preferences {
    my $self      = shift;
    my $wx_parent = shift;

    require Padre::Plugin::WebGUI::Preferences;
    my $prefs = Padre::Plugin::WebGUI::Preferences->new($self);
    $prefs->Show;
}

sub wgd_commands {
    use WGDev::Command;
    return WGDev::Command->command_list;
}

sub wgd_cmd {
    my ( $self, $cmd ) = @_;

    my $options = $self->main->prompt( "$cmd options", "wgd $cmd", "wgd_${cmd}_options" );
    if ( defined $options ) {
        $self->run_wgd("$cmd $options");
    }
    return;
}

sub run_wgd {
    my ( $self, $cmd ) = @_;
    local $ENV{WEBGUI_ROOT}   = '/data/WebGUI';
    local $ENV{WEBGUI_CONFIG} = 'dev.localhost.localdomain.conf';
    local $ENV{EDITOR}        = '/usr/local/bin/padre';

    #    $self->main->run_command( qq(/data/wre/prereqs/bin/perl /data/wre/prereqs/bin/wgd $cmd) );
    $self->main->run_command(qq(wgd $cmd));
}

sub show_about {
    my $self = shift;

    # Generate the About dialog
    my $about = Wx::AboutDialogInfo->new;
    $about->SetName("Padre::Plugin::WebGUI");
    $about->SetDescription( <<"END_MESSAGE" );
WebGUI developer tools for Padre
http://webgui.org
END_MESSAGE
    $about->SetVersion($VERSION);

    # Show the About dialog
    Wx::AboutBox($about);

    return;
}

# toggle_asset_tree
# Toggle the asset tree panel on/off
# N.B. The checkbox gets checked *before* this method runs
sub toggle_asset_tree {
    my $self = shift;

    return unless $self->ping;

    my $asset_tree = $self->asset_tree;
    if ( $self->{asset_tree_toggle}->IsChecked ) {
        $self->main->right->show($asset_tree);
        $asset_tree->update_gui;
    }
    else {
        $self->main->right->hide($asset_tree);
    }

    $self->main->aui->Update;
    $self->ide->save_config;

    return;
}

# toggle_logview
# Toggle the logview panel on/off
# N.B. The checkbox gets checked *before* this method runs
sub toggle_logview {
    my $self = shift;

    if ( $self->{logview_toggle}->IsChecked ) {
        my $logview = $self->logview;
        $self->main->bottom->show($logview);
        $logview->start( { files => $logfiles } );
    }
    else {

        # Use direct access so that we don't create instance unnecessarily
        if ( my $logview = $self->{logview} ) {
            $self->main->bottom->hide($logview);
        }
    }

    $self->main->aui->Update;

    return;
}

# private subroutine to return the current share directory location
sub _sharedir {
    return Cwd::realpath( File::Spec->join( File::Basename::dirname(__FILE__), 'WebGUI/share' ) );
}

# the icon displayed in the Padre plugin manager list
sub plugin_icon {

    # find resource path
    my $iconpath = File::Spec->catfile( _sharedir(), 'icons', 'wg_16x16.png' );

    # create and return icon
    return Wx::Bitmap->new( $iconpath, Wx::wxBITMAP_TYPE_PNG );
}

sub asset_tree {
    my $self = shift;

    $self->{asset_tree}
        or $self->{asset_tree} = do {
        require Padre::Plugin::WebGUI::Assets;
        Padre::Plugin::WebGUI::Assets->new($self);
        };
}

sub logview {
    my $self = shift;

    $self->{logview}
        or $self->{logview} = do {
        require Padre::Plugin::WebGUI::Logview;
        Padre::Plugin::WebGUI::Logview->new( $self->main );
        };
}

=head1 AUTHOR

Patrick Donelan C<< <pat at patspam.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-padre-plugin-webgui at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Padre-Plugin-WebGUI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Padre::Plugin::WebGUI


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Padre-Plugin-WebGUI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Padre-Plugin-WebGUI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Padre-Plugin-WebGUI>

=item * Search CPAN

L<http://search.cpan.org/dist/Padre-Plugin-WebGUI/>

=back

=head1 SEE ALSO

WebGUI - http://webgui.org
WGDev  - http://github.com/haarg/wgdev

=head1 COPYRIGHT & LICENSE

Copyright 2009 Patrick Donelan http://patspam.com, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

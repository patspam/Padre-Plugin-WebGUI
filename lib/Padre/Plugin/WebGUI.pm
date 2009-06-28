package Padre::Plugin::WebGUI;

use strict;
use warnings;
use base 'Padre::Plugin';
use Readonly;

=head1 NAME

Padre::Plugin::WebGUI - Developer tools for WebGUI

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01_02';

=head1 SYNOPSIS

cpan install Padre::Plugin::WebGUI;

Then use it via L<Padre>, The Perl IDE.

=head1 DESCRIPTION

Once you enable this Plugin under Padre, you'll get a brand new "WebGUI" menu with a bunch of nifty options.

=cut

# generate fast accessors
use Class::XSAccessor 
    getters => {
        wgd => 'wgd',
        asset_tree_visible => 'asset_tree_visible',
        log => 'log',
    };

# static field to contain reference to current plugin configuration
my $config;

sub plugin_config {
	return $config;
}

# The plugin name to show in the Plugin Manager and menus
sub plugin_name {
    Wx::gettext('WebGUI');
}

# Declare the Padre interfaces this plugin uses
sub padre_interfaces {
    'Padre::Plugin' => 0.29,
        ;
}

# called when the plugin is enabled
sub plugin_enable {
	my $self = shift;

	# Read the plugin configuration, and create it if it is not there
	$config = $self->config_read;
	if (!$config) {
		# no configuration, let us write some defaults
		$config = {
            WEBGUI_ROOT => '/data/WebGUI',
            WEBGUI_CONFIG => 'dev.localhost.localdomain.conf',
        };
		$self->config_write($config);
	}
	
	use Padre::Log;
	my $log = Padre::Log->new(level => 'debug');
	$self->{log} = $log;
	$self->log->debug("Logged initialised");
	
	my $wgd = eval {
        require WGDev;
        $self->log->debug("Loading WGDev using WEBGUI_ROOT: $config->{WEBGUI_ROOT} and WEBGUI_CONFIG: $config->{WEBGUI_CONFIG}");
        WGDev->new( $config->{WEBGUI_ROOT}, $config->{WEBGUI_CONFIG});
    };
    
    if ($@) {
        $self->log->error("The following error occurred when loading WGDev:\n\n $@");
        $self->main->error("The following error occurred when loading WGDev:\n\n $@");
        return;
    }
    
    if (!$wgd) {
        $self->log->error('Unable to instantiate wgd');
        $self->main->error('Unable to instantiate wgd');
        return;
    }
	
	$self->main->{webgui} = $self;
	$self->{wgd} = $wgd;

	return 1;
}

sub session {
    my $self = shift;
    
    my $session = eval {$self->wgd->session};
    if ($@) {
        $self->log->warn("Unable to get wgd session: $@");
        return;
    }
    return $session;
}

sub ping {
    my $self = shift;
    if (!$self->session) {
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
    if (my $asset_tree = $self->asset_tree) {
        $main->right->hide( $asset_tree );
    }
    if (my $logview = $self->logview) {
        $main->bottom->hide( $logview );
        $logview->stop;
    }    
    $main->show_output( 0 );#$self->main->menu->view->{output}->IsChecked );
    delete $main->{webgui};
    
    # Unload all private classese here, so that they can be reloaded
    require Class::Unload;
    Class::Unload->unload('Padre::Plugin::WebGUI::Task::Logview');
    Class::Unload->unload('Padre::Plugin::WebGUI::Logview');
    Class::Unload->unload('Padre::Plugin::WebGUI::Assets');
    Class::Unload->unload('Padre::Plugin::WebGUI::Preferences');
}

# The command structure to show in the Plugins menu
sub menu_plugins_simple {
    my $self = shift;

    Readonly my $wreservice => 'gksudo -- /data/wre/sbin/wreservice.pl';
    my $main = $self->main;

    my $menu = [
    
        "Reload WebGUI Plugin\tCtrl+Shift+R" => sub { $main->ide->plugin_manager->reload_current_plugin; },

        "WGDev Command" => [
            map {
                my $cmd = $_;
                "wgd $cmd" => sub { $self->wgd_cmd($cmd) }
                } $self->wgd_commands
        ],

        '---' => undef,

        "WRE Services" => [
            "Start" => [
                'All'      => sub { $main->run_command(qq($wreservice --start all")) },
                'Mysql'    => sub { $main->run_command(qq($wreservice --start mysql")) },
                'Modperl'  => sub { $main->run_command(qq($wreservice --start modperl")) },
                'Modproxy' => sub { $main->run_command(qq($wreservice --start modproxy")) },
                'SPECTRE'  => sub { $main->run_command(qq($wreservice --start specre")) },
            ],
            "Stop" => [
                'All'      => sub { $main->run_command(qq($wreservice --stop all")) },
                'Mysql'    => sub { $main->run_command(qq($wreservice --stop mysql")) },
                'Modperl'  => sub { $main->run_command(qq($wreservice --stop modperl")) },
                'Modproxy' => sub { $main->run_command(qq($wreservice --stop modproxy")) },
                'SPECTRE'  => sub { $main->run_command(qq($wreservice --stop specre")) },
            ],
            "Restart" => [
                'All'      => sub { $main->run_command(qq($wreservice --restart all")) },
                'Mysql'    => sub { $main->run_command(qq($wreservice --restart mysql")) },
                'Modperl'  => sub { $main->run_command(qq($wreservice --restart modperl")) },
                'Modproxy' => sub { $main->run_command(qq($wreservice --restart modproxy")) },
                'SPECTRE'  => sub { $main->run_command(qq($wreservice --restart specre")) },
            ],
            "Ping" => [
                'All'      => sub { $main->run_command(qq($wreservice --ping all")); },
                'Mysql'    => sub { $main->run_command(qq($wreservice --ping mysql")); },
                'Modperl'  => sub { $main->run_command(qq($wreservice --ping modperl")); },
                'Modproxy' => sub { $main->run_command(qq($wreservice --ping modproxy")); },
                'SPECTRE'  => sub { $main->run_command(qq($wreservice --ping specre")); },
            ],
        ],

        '---' => undef,

        'Online Resources' => [ $self->online_resources ],

        '---' => undef,

        "About" => sub { $self->show_about },
        
        "Asset Tree\tCtrl+Shift+S" => sub { $self->toggle_asset_tree },
    ];

    return $self->plugin_name => $menu;
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
	my $self = shift;
	my $wx_parent = shift;
	
	require Padre::Plugin::WebGUI::Preferences;
	my $prefs  = Padre::Plugin::WebGUI::Preferences->new($self);
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

sub toggle_asset_tree {
	my $self = shift;
#	my $on = ( @_ ? ( $_[0] ? 1 : 0 ) : 1 );
#	unless ( $on == $self->main->menu->view->{assets}->IsChecked ) {
#		$self->main->menu->view->{assets}->Check($on);
#	}
#	$self->main->config->set( webgui_assets => $on );
#	$self->main->config->write;

#    Wx::AboutBox(Wx::AboutDialogInfo->new);

    # Forcibly reset for now
#    if ($self->asset_tree) {
#        $self->main->right->hide( $self->asset_tree );
#        delete $self->asset_tree;
#        delete $self->{assets_shown};
#    }
    
    return unless $self->ping;
    
    my $asset_tree = $self->asset_tree;
    my $logview = $self->logview;
    if (!$self->asset_tree_visible) {
        $self->{asset_tree_visible} = 1;
		
		$self->main->right->show( $asset_tree );
		$self->main->bottom->show( $logview );
		
#		$asset_tree->update_gui;
		
		$logview->AppendText( "Loaded..\n" );
		$logview->start( { files => [ 
            '/data/wre/var/logs/webgui.log', 
            '/data/wre/var/logs/mylog.log', 
            '/data/wre/var/logs/modproxy.error.log', 
            '/data/wre/var/logs/modperl.error.log', 
            '/home/patspam/a', '/home/patspam/b' 
            ] } );

    } else {
        $self->{asset_tree_visible} = 0;
        $self->main->right->hide($asset_tree);
        $self->main->bottom->hide( $logview );
#        $logview->Remove( 0, $logview->GetLastPosition );
    }

	$self->main->aui->Update;
	$self->ide->save_config;

	return;
}

# private subroutine to return the current share directory location
sub _sharedir {
	return Cwd::realpath(
		File::Spec->join(File::Basename::dirname(__FILE__),'WebGUI/share')
	);
}

# the icon displayed in the Padre plugin manager list
sub plugin_icon {
    # find resource path
    my $iconpath = File::Spec->catfile( _sharedir(), 'icons', 'wg_16x16.png');

    # create and return icon
    return Wx::Bitmap->new( $iconpath, Wx::wxBITMAP_TYPE_PNG );
}

sub asset_tree {
    my $self = shift;
    
	$self->{asset_tree} or
		$self->{asset_tree} = do {
            require Padre::Plugin::WebGUI::Assets;
            Padre::Plugin::WebGUI::Assets->new( $self );
		};
}

sub logview {
    my $self = shift;
    
	$self->{logview} or
		$self->{logview} = do {
		    require Padre::Plugin::WebGUI::Logview;
            Padre::Plugin::WebGUI::Logview->new($self->main);
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

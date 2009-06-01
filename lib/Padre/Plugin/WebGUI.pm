package Padre::Plugin::WebGUI;

use strict;
use warnings;
use base 'Padre::Plugin';
use Readonly;
use WGDev;

=head1 NAME

Padre::Plugin::WebGUI - Developer tools for WebGUI

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01_01';

=head1 SYNOPSIS

cpan install Padre::Plugin::WebGUI;

Then use it via L<Padre>, The Perl IDE.

=head1 DESCRIPTION

Once you enable this Plugin under Padre, you'll get a brand new "WebGUI" menu with a bunch of nifty options.

=cut

# The plugin name to show in the Plugin Manager and menus
sub plugin_name {
    'WebGUI';
}

# Declare the Padre interfaces this plugin uses
sub padre_interfaces {
    'Padre::Plugin' => 0.29,
        ;
}

# The command structure to show in the Plugins menu
sub menu_plugins_simple {
    my $self = shift;

    Readonly my $wreservice => 'gksudo -- /data/wre/sbin/wreservice.pl';
    my $main = Padre->ide->wx->main;

    my $menu = [

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

sub wgd_commands {
    use WGDev::Command;
    return WGDev::Command->command_list;
}

sub wgd_cmd {
    my ( $self, $cmd ) = @_;

    my $main = Padre->ide->wx->main;
    my $options = $main->prompt( "$cmd options", "wgd $cmd", "wgd_${cmd}_options" );
    if ( defined $options ) {
        $self->wgd("$cmd $options");
    }
    return;
}

sub wgd {
    my ( $self, $cmd ) = @_;
    my $main = Padre->ide->wx->main;
    local $ENV{WEBGUI_ROOT}   = '/data/WebGUI';
    local $ENV{WEBGUI_CONFIG} = 'dev.localhost.localdomain.conf';
    local $ENV{EDITOR}        = '/usr/local/bin/padre';

    #    $main->run_command( qq(/data/wre/prereqs/bin/perl /data/wre/prereqs/bin/wgd $cmd) );
    $main->run_command(qq(wgd $cmd));
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

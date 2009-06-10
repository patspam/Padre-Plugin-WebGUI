package Padre::Plugin::WebGUI::Assets;

use 5.008;
use strict;
use warnings;
use File::Basename ();
use Params::Util qw{_INSTANCE};
use Padre::Current ();
use Padre::Util    ();
use Padre::Wx      ();

our $VERSION = '0.1';
our @ISA     = 'Wx::TreeCtrl';

use Class::XSAccessor getters => {
    plugin => 'plugin',
};

sub new {
    my $class  = shift;
    my $plugin = shift;
    my $self  = $class->SUPER::new( 
        $plugin->main->right, 
        -1, 
        Wx::wxDefaultPosition, 
        Wx::wxDefaultSize,
        Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS | Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE 
    );
    
    $self->{plugin} = $plugin;
    
    $self->SetIndent(10);
    $self->{force_next} = 0;

    Wx::Event::EVT_TREE_ITEM_ACTIVATED(
        $self, $self,
        sub {
            $self->on_tree_item_activated( $_[1] );
        },
    );

    $self->Hide;

    # create imagelist
    my $imglist = Wx::ImageList->new( 16, 16 );
    $self->AssignImageList($imglist);
    $imglist->Add( Padre::Wx::Icon::find('status/padre-plugin') );

    return $self;
}

sub wgd {
    $_[0]->plugin->wgd;
}

sub right {
    $_[0]->GetParent;
}

sub main {
    $_[0]->GetGrandParent;
}

sub gettext_label {

    #	Wx::gettext('assets');
    'Asset Tree';
}

sub clear {
    $_[0]->DeleteAllItems;
    return;
}

sub force_next {
    my $self = shift;
    if ( defined $_[0] ) {
        $self->{force_next} = $_[0];
        return $self->{force_next};
    }
    else {
        return $self->{force_next};
    }
}

#####################################################################
# Event Handlers

sub on_tree_item_activated {
    my ( $self, $event ) = @_;

    my $item = $self->GetPlData( $event->GetItem );
    return if not defined $item;

    # Generate the About dialog
    my $about = Wx::AboutDialogInfo->new;
    $about->SetName( 'aa' . $item->{name} );
    use Data::Dumper;
    $about->SetDescription( Dumper($item) );
    $about->SetVersion($VERSION);

    # Show the About dialog
    Wx::AboutBox($about);

    return;
}

sub ls_assets {
    my $self  = shift;
    my $asset = shift;
    my $wgd   = $self->wgd;

    $asset ||= WebGUI::Asset->getRoot( $wgd->session );

    my @data;
    my $children = $asset->getLineage( ["children"], { returnObjects => 1 } );
    for my $child ( @{$children} ) {
        my $icon = $child->getIcon;
        $icon =~ s{.*/}{};
        my %item = (
            name => $child->getMenuTitle,
            id   => $child->getId,
            type => $child->getName,
            icon => $icon,
        );
        $item{children} = $self->ls_assets($child);

        push @data, \%item;
    }
    return \@data;
}

sub update_gui {
    my ($self) = @_;

    return if not Padre->ide->wx;

    my $assets = $self;    #$self->main->assets;
    $assets->Freeze;
    $assets->clear;

    my $root = $assets->AddRoot(

        #		Wx::gettext('assets'),
        'Asset Tree',
        -1,
        -1,
        Wx::TreeItemData->new('')
    );

    _update_treectrl( $assets, $self->ls_assets, $root );

    Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK( $assets, $assets, \&_on_tree_item_right_click, );

    $assets->GetBestSize;

    $assets->Thaw;
}

sub _on_tree_item_right_click {
    my ( $self, $event ) = @_;

    my $showMenu = 0;
    my $menu     = Wx::Menu->new;
    my $itemData = $self->GetPlData( $event->GetItem );

    if ( defined $itemData ) {
        my $goTo = $menu->Append( -1, "Export Package" );    #Wx::gettext("Open File") );
        Wx::Event::EVT_MENU(
            $self, $goTo,
            sub {
                $self->on_tree_item_activated($event);
            },
        );
        $showMenu++;
    }

    if (   defined($itemData)
        && defined( $itemData->{type} )
        && ( $itemData->{type} eq 'modules' || $itemData->{type} eq 'pragmata' ) )
    {
        my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
        Wx::Event::EVT_MENU(
            $self, $pod,
            sub {

                # TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
                require Padre::Wx::DocBrowser;
                my $help = Padre::Wx::DocBrowser->new;
                $help->help( $itemData->{name} );
                $help->SetFocus;
                $help->Show(1);
                return;
            },
        );
        $showMenu++;
    }

    if ( $showMenu > 0 ) {
        my $x = $event->GetPoint->x;
        my $y = $event->GetPoint->y;
        $self->PopupMenu( $menu, $x, $y );
    }

    return;
}

my $image_lookup;

sub get_item_image {
    my $self    = shift;
    my $icon    = shift;
    my $imglist = $self->GetImageList;
    if ( !$image_lookup->{$icon} ) {
        my $index = $imglist->Add(
            Wx::Bitmap->new( "/data/WebGUI/www/extras/assets/small/" . $icon, Wx::wxBITMAP_TYPE_GIF ) );
        $image_lookup->{$icon} = $index;
    }
    return $image_lookup->{$icon} || 0;
}

sub _update_treectrl {
    my ( $self, $items, $parent ) = @_;

    foreach my $item ( @{$items} ) {
        my $node = $self->AppendItem(
            $parent,
            $item->{name},
            -1, -1,
            Wx::TreeItemData->new(
                {   id   => $item->{id},
                    name => $item->{name},
                    type => $item->{type},
                    icon => $item->{icon},
                }
            ),
        );
        $self->SetItemTextColour( $node, Wx::Colour->new( 0x00, 0x00, 0x7f ) );
        $self->SetItemImage( $node, $self->get_item_image( $item->{icon} ) );

        # Recurse, adding children to $node
        _update_treectrl( $self, $item->{children}, $node );
    }

    return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

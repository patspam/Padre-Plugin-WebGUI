package Padre::Plugin::WebGUI::Assets;

use 5.008;
use strict;
use warnings;
use Padre::Current ();
use Padre::Util    ();
use Padre::Wx      ();
use base 'Wx::TreeCtrl';
use Data::Dumper;

# generate fast accessors
use Class::XSAccessor getters => {
    plugin => 'plugin',
    connected => 'connected',
};

# constructor
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

    # Register event handlers..    
    Wx::Event::EVT_TREE_ITEM_ACTIVATED(
        $self, $self,
        sub {
            $self->on_tree_item_activated( $_[1] );
        },
    );

    $self->Hide;

    # Create image list
    my $imglist = Wx::ImageList->new( 16, 16 );
    $self->AssignImageList($imglist);
    $imglist->Add( Padre::Wx::Icon::find('status/padre-plugin') );

    return $self;
}

# accessors
sub wgd { $_[0]->plugin->wgd }
sub right { $_[0]->GetParent }
sub main { $_[0]->GetGrandParent }
sub gettext_label { Wx::gettext('Asset Tree') }
sub clear { $_[0]->DeleteAllItems }
sub log { $_[0]->plugin->log }


sub update_gui {
    my $self = shift;
    if ($self->connected) {
        $self->update_gui_connected;
    } else {
        $self->update_gui_disconnected;
    }
}

sub update_gui_disconnected {
    my $self = shift;
    
    $self->{connected} = 0;

    $self->Freeze;
    $self->clear;
    
    my $root = $self->AddRoot(
		Wx::gettext('Asset Tree'),
        -1,
        -1,
        Wx::TreeItemData->new('')
    );
    my $connect = $self->AppendItem(
        $root,
        'Connect',
        -1, 
        -1,
        Wx::TreeItemData->new({connect => 1}),
    );
    $self->SetItemTextColour( $connect, Wx::Colour->new( 0x00, 0x00, 0x7f ) );
    $self->SetItemImage( $connect, 0 );
    $self->GetBestSize;
    
    $self->Thaw;
}

sub update_gui_connected {
    my $self = shift;
    
    $self->{connected} = 1;
    
    # Show loading indicator
    $self->Freeze;
    $self->clear;
    
    my $tmp_root = $self->AddRoot(
		Wx::gettext('Asset Tree'),
        -1,
        -1,
        Wx::TreeItemData->new('')
    );
    my $status = $self->AppendItem(
        $tmp_root,
        'Loading..',
        -1, 
        -1,
        Wx::TreeItemData->new({loading => 1}),
    );
    $self->SetItemTextColour( $status, Wx::Colour->new( 0x00, 0x00, 0x7f ) );
    $self->SetItemImage( $status, 0 );
    $self->GetBestSize;
    
    $self->Thaw;
    
    # Force window update
    $self->Update;
    
    # Now actually connect..
    $self->Freeze;
    $self->clear;

    my $root = $self->AddRoot(
		Wx::gettext('Asset Tree'),
        -1,
        -1,
        Wx::TreeItemData->new('')
    );
    my $refresh = $self->AppendItem(
        $root,
        'Refresh',
        -1, 
        -1,
        Wx::TreeItemData->new({refresh => 1}),
    );
    $self->SetItemTextColour( $refresh, Wx::Colour->new( 0x00, 0x00, 0x7f ) );
    $self->SetItemImage( $refresh, 0 );

    update_treectrl( $self, $self->build_asset_tree, $root );

    # Register right-click event handler
    Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK( $self, $self, \&on_tree_item_right_click, );

    $self->GetBestSize;
    $self->Thaw;
}

# generate the list of assets
sub build_asset_tree {
    my $self    = shift;
    my $wgd     = $self->wgd;
    my $session = $wgd->session;

    require WebGUI::Asset;

    my $root = WebGUI::Asset->getRoot($session);
    my $assets = $root->getLineage( [ "self", "descendants" ], { returnObjects => 1 } );
    
    # Build a hash mapping each assetId to an array of children for that asset
    my %tree;
    foreach my $asset (@$assets) {
        # Add this new asset to the tree, initially with no children
        $tree{ $asset->getId } = [];
        
        # Push this asset onto its parent's list of children
        push @{ $tree{ $asset->get('parentId') } }, $asset;
    }

    # Serialise the tree and turn it into a recursive tree hash as requried by update_treectrl
    my $serialise;
    $serialise = sub {
        my $asset = shift or return;
        my $node = {
            name => $asset->getMenuTitle,
            id   => $asset->getId,
            type => $asset->getName,
            url  => $asset->getUrl,
            icon => File::Basename::fileparse( $asset->getIcon ),
        };
        
        # Recursively serialise children and add to node's children property
        push( @{ $node->{children} }, $serialise->($_) ) for @{ $tree{ $asset->getId } };
        return $node;
    };

    # Our tree starts with all the children of the root node
    return $serialise->($root)->{children};
}

sub on_tree_item_right_click {
    my ( $self, $event ) = @_;

    my $showMenu = 0;
    my $menu     = Wx::Menu->new;
    my $itemData = $self->GetPlData( $event->GetItem );

    if ( defined $itemData ) {
        my $submenu;
        
        $submenu = $menu->Append( -1, Wx::gettext("Details..") );
        Wx::Event::EVT_MENU(
            $self, $submenu,
            sub {
                $self->on_tree_item_activated($event, { action => 'details' });
            },
        );
        
        $submenu = $menu->Append( -1, Wx::gettext("Export Package") );
        Wx::Event::EVT_MENU(
            $self, $submenu,
            sub {
                $self->on_tree_item_activated($event, {action => 'export' });
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


# event handler for item activation
sub on_tree_item_activated {
    my ( $self, $event, $opts ) = @_;
    $opts ||= {};

    # Get the target item
    my $item = $self->GetPlData( $event->GetItem );
    return if not defined $item;
    
    if ($item->{connect}) {
        $self->update_gui_connected;
        return;
    }
    
    if ($item->{refresh}) {
        $self->update_gui_connected;
        return;
    }    
    
    if ($opts->{action} eq 'details') {
        $self->main->error( <<END_DETAILS );
Id: \t\t\t $item->{id}
Type: \t\t $item->{type}
Url: \t\t\t $item->{url}
Menu Title: \t $item->{name}
END_DETAILS
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

sub update_treectrl {
    my ( $self, $items, $parent ) = @_;

    foreach my $item ( @{$items} ) {
        my $node = $self->AppendItem(
            $parent,
            $item->{name},
            -1, -1,
            Wx::TreeItemData->new({%$item}),
        );
        $self->SetItemTextColour( $node, Wx::Colour->new( 0x00, 0x00, 0x7f ) );
        $self->SetItemImage( $node, $self->get_item_image( $item->{icon} ) );

        # Recurse, adding children to $node
        update_treectrl( $self, $item->{children}, $node );
    }

    return;
}

1;

# Copyright 2009 Patrick Donelan
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

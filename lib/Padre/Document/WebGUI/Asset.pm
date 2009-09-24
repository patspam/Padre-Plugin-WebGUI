package Padre::Document::WebGUI::Asset;

use 5.008;
use strict;
use warnings;
use Padre::Document ();
use Carp;

our @ISA = 'Padre::Document';

use Class::XSAccessor getters => {
    wgd => 'wgd',
    asset => 'asset',
};

sub get_mimetype { 'application/x-webgui-asset' }

sub basename { $_[0]->filename }

# Anything more appropriate?
sub dirname { $_[0]->basename }

sub time_on_file { $_[0]->asset->get('revisionDate') }

sub load_file { $_[0]->load_asset }

sub load_asset {
    my ($self, $wgd, $asset) = @_;
    
    $wgd ||= $self->wgd;
    $asset ||= $self->asset;
    
    return unless $wgd;
    return unless $asset && $asset->isa('WebGUI::Asset');
    
    Padre::Util::debug("Loading asset " . $asset->getUrl);
    $self->set_errstr('');
    
    $self->{wgd} = $wgd;
    $self->{asset} = $asset;
    $self->{_timestamp} = $self->time_on_file;
    
    # Set a fake filename, so that we the file isn't considered 'new', and so that we don't have to set the 
    # title via: $main->current->notebook->SetPageText( $main->current->notebook->GetSelection, ' ' . $asset->getName );
    $self->{filename} = '[wg] ' . $asset->getMenuTitle;
    
    # Set text (a la Padre::Document::load_file)
    my $serialised = $wgd->asset->serialize($asset);
    
	require Padre::Locale;
	$self->{encoding} = Padre::Locale::encoding_from_string($serialised);
	$serialised = Encode::decode( $self->{encoding}, $serialised );

	$self->text_set($serialised);
	$self->{original_content} = $self->text_get;
	$self->colourize;
}

# Override Padre::Document::save_file
sub save_file {
    my $self = shift;
    
    my $wgd = $self->wgd;
	my $asset = $self->asset;
	return unless $asset && $asset->isa('WebGUI::Asset');
	
    # Two saves in the same second will cause asset->addRevision to explode
    return 1 if $self->last_sync && $self->last_sync == time;
    
    Padre::Util::debug("Saving asset to url: " . $asset->getUrl);
    
	my $serialised = $self->text_get;
	my $deserialised = $wgd->asset->deserialize($serialised);
	
	require WebGUI::VersionTag;
    my $version_tag = WebGUI::VersionTag->getWorking( $wgd->session );
    $version_tag->set( { name => 'Padre Asset Editor' } );
    $asset->addRevision(
        $deserialised,
        undef,
        {
            skipAutoCommitWorkflows => 1,
            skipNotification        => 1,
        } 
    );   
    $version_tag->commit;
    
    $self->{_timestamp} = $self->time_on_file;
    
	return 1;
}

1;
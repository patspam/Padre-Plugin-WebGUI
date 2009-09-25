package Padre::Document::WebGUI::Asset::Template;

use 5.008;
use strict;
use warnings;
use Padre::Document::WebGUI::Asset;
use Carp;

our @ISA = 'Padre::Document::WebGUI::Asset';

#sub get_mimetype { 'application/x-webgui-asset-template' }

#sub get_asset_content {
#    my $self = shift;
#    Padre::Util::debug('using TEMPLATE');
#    Padre::Util::debug($self->asset->{template});
#    return $self->asset->{template};
#}
#
#sub set_asset_content {
#    my $self = shift;
#	$self->asset->{template} = $self->text_get;
#	Padre::Util::debug('using TEMPLATE');
#}

1;
package C::Ausweis;

use strict;
use warnings;

#use Image::Magick;
use Clib::Mould;

##################################################
###     Основной список
###     Код модуля: 95
#############################################

sub _item {
    my $self = shift;
    
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    return $item;
}


sub file {
    my ($self, $eid, $field) = @_;

    my $d = $self->d;
    
    my ($rec) = 
        $self->model('PreeditField')->search({ eid => $eid, param => $field });
    $rec || return $self->state(-000105, '');
    
    my $file = $rec->{value};
    
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('preedit', $rec->{eid})."/$file";
}


1;

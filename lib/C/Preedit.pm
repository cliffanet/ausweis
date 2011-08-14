package C::Preedit;

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
    
    $item->{field} = sub {
        return $item->{_field} if $item->{_field};
        $item->{_field} = $self->model('PreeditField')->get_value($item);
        if ($item->{type} eq 'Ausweis') {
            $item->{_field} = C::Ausweis::_item($self, $item->{_field});
        }
        else {
            $item->{_field} = $self->ToHtml($item->{_field});
        }
        $item->{_field};
    };
    
    $item->{href_file} = sub { $self->href($::disp{PreeditFile}, $item->{id}, shift) };
    
    return $item;
}

sub showitem {
    my ($self) = @_;
    
    return unless $self->rights_exists_event($::rPreedit);
    my $d = $self->d;
    
    $self->patt(TITLE => $text::titles{"preedit_showitem"});
    $self->view_select->subtemplate("preedit_showitem.tt");
    
    my $afterid = $self->req->param_dig('afterid');
    my ($pre) = (($d->{pre}) = 
        map { _item($self, $_) } 
        $self->model('Preedit')->search(
            { modered => 0, $afterid ? (id => { '>' => $afterid }) : () },
            { order_by => 'id', limit => 1 }
        ));
    
    $d->{type} = $pre ? lc $pre->{tbl} : '';
    $pre || return;
    
    $d->{subtmpl_name} = "preedit_$d->{type}.tt";
    $d->{field} = $pre->{field};
    $d->{field_exists} = sub { exists $d->{field}->()->{$_[0]} };
    
    $d->{href_skipitem} = $self->href($::disp{PreeditShowItem})."?afterid=$pre->{id}";
    
    if ($pre->{tbl} eq 'Ausweis') {
        ($d->{rec}) = map { C::Ausweis::_item($self, $_) }
            $self->model('Ausweis')->search({ id => $pre->{recid} }, { prefetch => [qw/command blok/] });
    }
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

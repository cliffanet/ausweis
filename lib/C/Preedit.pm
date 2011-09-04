package C::Preedit;

use strict;
use warnings;

#use Image::Magick;
use Clib::Mould;

##################################################
###     Îñíîâíîé ñïèñîê
###     Êîä ìîäóëÿ: 95
#############################################

sub _item {
    my $self = shift;
    
    my $item = $self->ToHtml(shift, 1) || return;
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
            { order_by => 'id', prefetch => 'user', limit => 1 }
        ));
    
    $d->{type} = $pre ? lc $pre->{tbl} : '';
    $pre || return;
    
    $d->{subtmpl_name} = "preedit_$d->{type}.tt";
    $d->{field} = $pre->{field};
    $d->{field_exists} = sub { exists $d->{field}->()->{$_[0]} };
    
    $d->{href_skipitem} = $self->href($::disp{PreeditShowItem})."?afterid=$pre->{id}";
    $d->{href_op} = $self->href($::disp{PreeditOp}, $pre->{id});
    
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

sub op {
    my ($self, $eid) = @_;
    
    return unless $self->rights_exists_event($::rPreedit);
    my $d = $self->d;
    
    my ($pre) = 
        $self->model('Preedit')->search({ id => $eid, modered => 0 });
    $pre || return $self->state(-000105, '');
    
    my %p = (visibled => 1);
    $p{modered} = $self->req->param_dig('modered')
        || return $self->state(-000101, '');
    $p{comment} = $self->req->param_str('comment');
        
    my $ret;
    if ($p{modered} > 0) {
        my $fields = $self->model('PreeditField')->get_value($pre->{id})
            if ($pre->{op} eq 'C') || ($pre->{op} eq 'E');
        if ($pre->{op} eq 'C') {
            $ret = $self->model($pre->{tbl})->create($fields);
            $pre->{recid} = $self->model($pre->{tbl})->insertid;
            $p{recid} = $pre->{recid};
        } elsif ($pre->{op} eq 'E') {
            $ret = $self->model($pre->{tbl})->update($fields, { id => $pre->{recid} });
        } elsif ($pre->{op} eq 'D') {
            $ret = $self->model($pre->{tbl})->delete({ id => $pre->{recid} });
        }
        
        # Çàãğóçêà ôàéëîâ
        if (($pre->{tbl} eq 'Ausweis') && $fields && $fields->{photo}) {
            Func::MakeCachDir('ausweis', $pre->{recid})
                || return $self->state(-900102, '');
            my $photo = Func::ImgCopy($self, 
                Func::CachDir('preedit', $pre->{id})."/".$fields->{photo},
                Func::CachDir('ausweis', $pre->{recid}), 'photo')
                    || return $self->state(-900102, '');
            my $regen = (1<<($::regen{photo}-1));
            $self->model('Ausweis')->update(
                { 
                    regen   => \ "`regen` | $regen",
                    photo   => $photo,
                },
                { id => $pre->{recid} }
            ) || return $self->state(-000104, '');
        }
    }
    else {
        $ret = 1;
    }
    $ret || return $self->state(-000104, '');
    
    # Îáíîâëÿåì ñòàòóñ Preedit
    $self->model('Preedit')->update(\%p, { id => $eid })
        || return $self->state(-000104, '');
    
    return $self->state($ret > 0 ? 950100 : -000106, '');
}


1;

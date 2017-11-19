package C::Preedit;

use strict;
use warnings;

#use Image::Magick;
use Clib::Mould;
use Encode '_utf8_on', 'encode';

##################################################
###     Основной список
###     Код модуля: 95
#############################################

sub _item {
    my $self = shift;
    
    
    my $aus = C::Ausweis::_item($self, delete $_[0]->{ausweis}) if $_[0]->{ausweis};
    my $item = $self->ToHtml(shift, 1) || return;
    my $id = $item->{id};
    
    $item->{ausweis} = $aus if $aus;
    $item->{ausweis}->{id} ||= 0 if $aus;
    
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

sub first :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('preedit_first') || return;
    $self->template("preedit_first");
    
    my $afterid = $self->req->param_dig('afterid');
    my ($pre) = 
        $self->model('Preedit')->search(
            { modered => 0, $afterid ? (id => { '>' => $afterid }) : () },
            { order_by => 'id', prefetch => 'user', limit => 1 }
        );
    
    $pre || return;
    
    my $field = $self->model('PreeditField')->get_value($pre);
    
    my %d = ();
    if ($pre->{tbl} eq 'Ausweis') {
        $d{file_photo} = 'photo.site.jpg';
        ($d{aus}) =
            $self->model('Ausweis')->search({ id => $pre->{recid} }, { prefetch => [qw/command blok/] });
        $d{field_exists} = {
            map { ($_ => exists $field->{$_}) }
            $d{aus} ?
                (keys %{ $d{aus} }) :
                (keys %{ $self->model('Ausweis')->columns })
        };
        $d{cmd} = $self->model('Command')->byId($field->{cmdid}) if $field->{cmdid};
        $d{nick_exists} = [
                $self->model('Ausweis')->search(
                    { 
                        blocked => 0, 
                        nick => { LIKE => "\%$field->{nick}\%" },
                        $d{aus} ? (id => { '!=' => $d{aus}->{id} }) : (),
                    }, 
                    { prefetch => 'command' }
                )
            ];
        $d{fio_exists} = [
                map { C::Ausweis::_item($self, $_) }
                $self->model('Ausweis')->search(
                    { 
                        blocked => 0, 
                        fio => { LIKE => "\%$field->{fio}\%" },
                        $d{aus} ? (id => { '!=' => $d{aus}->{id} }) : (),
                    }, 
                    { prefetch => 'command' }
                )
            ];
    }
    
    return
        pre => $pre,
        field => $field,
        %d
}

sub file :
    ParamObj('pre', 0)
    ParamRegexp('[a-zA-Z\d]+')
    ReturnPatt
{
    my ($self, $pre, $field) = @_;

    $pre || return $self->notfound;
    
    my ($pf) = 
        $self->model('PreeditField')->search({ eid => $pre->{id}, param => $field });
    $pf || return $self->notfound;
    
    my $d = $self->d;
    $self->view_select('File');
    
    my $file = $pf->{value};
    $d->{file} = Func::CachDir('preedit', $pre->{id})."/$file";
}

sub op :
    ParamObj('pre', 0)
    ReturnOperation
{
    my ($self, $pre) = @_;
    
    $self->rcheck('preedit_op') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $pre || return $self->nfound();
    
    my %p = (visibled => 1);
    $p{modered} = $self->req->param_dig('modered')
        || return $self->state(-000101, '');
    $p{comment} = $self->req->param_str('comment');
    _utf8_on($p{comment});
        
    my $ret;
    if ($p{modered} > 0) {
        my $fields = ($pre->{op} eq 'C') || ($pre->{op} eq 'E') ?
            $self->model('PreeditField')->get_value($pre->{id}) : undef;
        if ($pre->{op} eq 'C') {
            $ret = $self->model($pre->{tbl})->create($fields);
            $pre->{recid} = $self->model($pre->{tbl})->insertid;
            $p{recid} = $pre->{recid};
        } elsif ($pre->{op} eq 'E') {
            $ret = $self->model($pre->{tbl})->update($fields, { id => $pre->{recid} });
        } elsif ($pre->{op} eq 'D') {
            $ret = $self->model($pre->{tbl})->delete({ id => $pre->{recid} });
        }
        
        # Загрузка файлов
        if (($pre->{tbl} eq 'Ausweis') && $fields && $fields->{photo} && $ret) {
            Func::MakeCachDir('ausweis', $pre->{recid})
                || return (error => 900102, href => '', errlog => ['Can\'t make ausweis dir: %s', $!]);
            my $photo = Func::ImgCopy($self, 
                Func::CachDir('preedit', $pre->{id})."/".$fields->{photo},
                Func::CachDir('ausweis', $pre->{recid}), 'photo')
                    || return (error => 900102, href => '', errlog => ['Can\'t copy ausweis photo: %s', $!]);
            my $regen = (1<<($::regen{photo}-1));
            $self->model('Ausweis')->update(
                { 
                    regen   => \ "`regen` | $regen",
                    photo   => $photo,
                },
                { id => $pre->{recid} }
            ) || return (error => 000104, href => '');
        }
    }
    else {
        $ret = 1;
    }
    $ret || return (error => 000104, href => '');
    
    # Обновляем статус Preedit
    $self->model('Preedit')->update(\%p, { id => $pre->{id} })
        || return (error => 000104, href => '');
    
    return ($ret > 0 ? (ok => 950100) : (error => 000106), href => '');
}



sub hide :
    ParamObj('pre', 0)
    ReturnOperation
{
    my ($self, $pre) = @_;
    
    $self->rcheck('preedit_hide') || return $self->rdenied;
    $pre || return $self->nfound();
    return $self->rdenied() if $pre->{uid} != $self->user->{id};
    $self->d->{read_only} && return $self->cantedit();
    
    $self->model('Preedit')->update({ visibled => 0 }, { id => $pre->{id} })
        || return (error => 000104, href => '');
    
    return (ok => 950400, href => '');
}

sub cancel :
    ParamObj('pre', 0)
    ReturnOperation
{
    my ($self, $pre) = @_;
    
    $self->rcheck('preedit_cancel') || return $self->rdenied;
    $pre || return $self->nfound();
    if ($pre->{uid} != $self->user->{id}) {
        $self->rcheck('preedit_cancel_all') || return $self->rdenied;
    }
    $self->d->{read_only} && return $self->cantedit();
    
    return (error => 950501, href => '') if $pre->{modered} != 0;
    
    $self->model('Preedit')->update(
        { 
            modered => $pre->{uid} == $self->user->{id} ? -2 : -1,
            visibled=> 1,
        }, 
        { id => $pre->{id} }
    ) || return (error => 000104, href => '');
    
    return (ok => 950500, href => '');
}



1;

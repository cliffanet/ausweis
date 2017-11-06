package C::Blok;

use strict;
use warnings;

use Encode '_utf8_on', 'encode';

##################################################
###     Список команд
###     Код модуля: 97
#############################################

sub _item {
    my $self = shift;
    my $item = $self->d->{excel} ? shift : $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{BlokShow}, $item->{id}, 'info');
        $item->{href_edit}      = $self->href($::disp{BlokShow}, $item->{id}, 'edit');
        $item->{href_del}       = $self->href($::disp{BlokDel}, $item->{id});
        $item->{href_delete}    = $self->href($::disp{BlokDel}, $item->{id});
        
        $item->{href_file}      = sub { $self->href($::disp{BlokFile}, $item->{id}, shift) };
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('blok', $item->{id})."/$file";
        };
        
        $item->{href_cmd_adding}= $self->href($::disp{CommandAdding}."?blkid=%d", $id);
        
        Func::regen_stat($self, $item);
    }
    
    return $item;
}

sub _list {
    my $self = shift;
    return $self->d->{blk}->{_list} ||= [
        map { _item($self, $_); }
        $self->model('Blok')->search({},{order_by=>'name'})
    ];
}

sub _hash {
    my $self = shift;
    return $self->d->{blk}->{_hash} ||= {
        map { ($_->{id} => $_) }
        @{ _list($self) }
    };
}

sub list :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('blok_list') || return;
    $self->template("blok_list", 'CONTENT_result');
    
    my $srch = {};
    my $s = $self->req->param_str('srch');
    _utf8_on($s);
    if (my $name = $s) {
        $name =~ s/([%_])/\\$1/g;
        $name =~ s/\*/%/g;
        $name =~ s/\?/_/g;
        $name = "%$name" if $name !~ /^%/;
        $name .= "%" if $name !~ /%$/;
        #$name .= "%" if $name !~ /^(.*[^\\])?%$/;
        $srch->{name} = { LIKE => $name };
    }

    
    my @list = $self->model('Blok')->search(
            $srch,
            {
                order_by => 'name',
            },
        );
    
    return
        srch => $s,
        list => \@list,
}

sub info :
    ParamObj('blok', 0)
    ReturnPatt
{
    my ($self, $blok) = @_;

    $self->view_rcheck('blok_info') || return;
    $blok || return $self->notfound;
    if (!$self->user->{blkid} || ($self->user->{blkid} != $blok->{id})) {
        $self->view_rcheck('blok_info_all') || return;
    }
    $self->template("blok_info");
    
    my $filelogo = 'logo.site.jpg';
    my $flsize = -s Func::CachDir('blok', $blok->{id})."/$filelogo";
    
    my @cmd =
        $self->model('Command')->search(
            { blkid => $blok->{id} },
            { order_by => 'name' },
        );
    
    return
        blok => $blok,
        file_logo => $filelogo,
        file_logo_size => $flsize,
        cmd_list => \@cmd,
}  

sub my :
    ReturnPatt
{
    my ($self) = @_;
    
    my $user = $self->user || return $self->rdenied;
    my $blkid = $self->user->{blkid} || return $self->notfound;
    my $blok = $self->obj(blok => [$blkid]) || return $self->notfound;
    
    return info($self, $blok->{$blkid});
}

sub edit :
    ParamObj('blok', 0)
    ReturnPatt
{
    my ($self, $blok) = @_;

    $self->view_rcheck('blok_edit') || return;
    $blok || return $self->notfound;
    if (!$self->user->{blkid} || ($self->user->{blkid} != $blok->{id})) {
        $self->view_rcheck('blok_edit_all') || return;
    }
    $self->view_can_edit() || return;
    $self->template("blok_edit");
    
    my %form = %$blok;
    if ($self->req->params() && (my $fdata = $self->ParamData)) {
        $form{$_} = $fdata->{$_} foreach grep { exists $fdata->{$_} } keys %form;
    }
    
    return
        blok => $blok,
        form => \%form,
}

sub file :
    ParamObj('blok', 0)
    ParamRegexp('[a-zA-Z\d\.\-]+')
    ReturnPatt
{
    my ($self, $blok, $file) = @_;

    $self->view_rcheck('blok_file') || return;
    $blok || return $self->notfound;
    if (!$self->user->{blkid} || ($self->user->{blkid} != $blok->{id})) {
        $self->view_rcheck('blok_file_all') || return;
    }
    my $d = $self->d;
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('blok', $blok->{id})."/$file";
    
    if (my $t = $::BlokFile{$file}) {
        $d->{type} = $t->[0]||'';
        my $m = Clib::Mould->new();
        $d->{filename} = $m->Parse(data => $t->[1]||'', pattlist => $blok, dot2hash => 1);
    }
}

sub adding {
    my ($self) = @_;

    return unless $self->rights_check_event($::rBlokEdit, $::rAll);
    
    $self->can_edit() || return;
    
    $self->patt(TITLE => $text::titles{"blok_add"});
    $self->view_select->subtemplate("blok_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{BlokAdd});
    
        # Автозаполнение полей, если данные из формы не приходили
    $d->{form} =
        { map { ($_ => '') } qw/name/ };
    if ($self->req->params()) {
        # Данные из формы - либо после ParamParse, либо напрямую данные
        my $fdata = $self->ParamData(fillall => 1);
        if (keys %$fdata) {
            $d->{form} = { %{ $d->{form} }, %$fdata };
        } else {
            $d->{form}->{$_} = $self->req->param($_) foreach $self->req->params();
        }
    }
    #$d->{form}->{comment_nobr} = $self->ToHtml($d->{form}->{comment});
    #$d->{form}->{comment} = $self->ToHtml($d->{form}->{comment}, 1);
}

sub set {
    my ($self, $id) = @_;
    my $is_new = !defined($id);
    
    my $dirUpload = Func::SetTmpDir($self)
        || return !$self->state(-900101, '');
    
    return unless $self->rights_exists_event($::rBlokEdit);
    if (!$id || !$self->user->{blkid} || ($self->user->{blkid} != $id)) {
        return unless $self->rights_check_event($::rBlokEdit, $::rAll);
    }
    
    $self->can_edit() || return;
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Blok')->search({ id => $id })) if $id;
    if (!$is_new && (!$rec || !$rec->{id})) {
        return $self->state(-000105, '');
    }
    
    # Проверяем данные из формы
    if (!$self->ParamParse(model => 'Blok', is_create => $is_new)) {
        $self->state(-000101);
        return $is_new ? adding($self) : edit($self, $id);
    }
    
    # Сохраняем данные
    my $ret = $self->ParamSave( 
        model           => 'Blok', 
        $is_new ?
            ( insert => \$id ) :
            ( 
                update => { id => $id }, 
                preselect => $rec
            ),
    );
    if (!$ret) {
        $self->state(-000104);
        return $is_new ? adding($self) : edit($self, $id);
    }
    
    # Загрузка логотипа
    if (my $file = $self->req->param("photo")) {
        Func::MakeCachDir('blok', $id)
            || return $self->state(-900102, '');
        my $photo = Func::ImgCopy($self, "$dirUpload/$file", Func::CachDir('blok', $id), 'logo')
            || return $self->state(-900102, '');
        $self->model('Blok')->update(
            { 
                regen   => (1<<($::regen{logo}-1)),
                photo   => $photo,
            },
            { id => $id }
        ) || return $self->state(-000104, '');
        unlink("$dirUpload/$file");
    }
    
    # Статус с редиректом
    return $self->state($is_new ? 970100 : 970200,  $self->href($::disp{BlokShow}, $id, 'info') );
}

sub del {
    my ($self, $id) = @_;
    
    return unless $self->rights_check_event($::rBlokEdit, $::rAll);
    
    $self->can_edit() || return;
    
    my ($rec) = $self->model('Blok')->search({ id => $id });
    $rec || return $self->state(-000105);
    
    $self->model('Blok')->delete({ id => $id })
        || return $self->state(-000104, '');
        
    # Убираем блок у команд
    $self->model('Command')->update(
        { blkid => 0 },
        { blkid => $id },
    ) || return $self->state(-000104, '');
    
    # Убираем блок у аусвайсов
    $self->model('Ausweis')->update(
        { blkid => 0 },
        { blkid => $id },
    ) || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(970300, $self->href($::disp{BlokList}) );
}



1;

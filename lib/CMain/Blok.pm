package CMain::Blok;

use strict;
use warnings;

use Encode '_utf8_on', 'encode';

##################################################
###     Список команд
###     Код модуля: 97
#############################################

=pod
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
=cut

sub list :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('blok_list') || return;
    $self->template("blok_list", 'CONTENT_result');
    
    my $noblock_count = 0;
    
    my @qsrch = ();
    my $srch = {};
    my $s = $self->req->param_str('srch');
    _utf8_on($s);
    push @qsrch, { f => 'srch', val => $s };
    if (my $name = $s) {
        $name =~ s/([%_])/\\$1/g;
        $name =~ s/\*/%/g;
        $name =~ s/\?/_/g;
        $name = "%$name" if $name !~ /^%/;
        $name .= "%" if $name !~ /%$/;
        #$name .= "%" if $name !~ /^(.*[^\\])?%$/;
        $srch->{name} = { LIKE => $name };
    }
    else {
        $noblock_count = $self->model('Command')->count({ blkid => 0 });
    }

    
    my @list = $self->model('Blok')->search(
            $srch,
            {
                order_by => 'name',
                join => 'command',
                '+columns' => ['COUNT(`command`.`id`) as `blok.cmdcount`'],
                group_by => 'id',
            },
        );
    
    return
        srch => $s,
        qsrch => $self->qsrch(@qsrch),
        noblock_count => $noblock_count,
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
        if (keys %$fdata) {
            $form{$_} = $fdata->{$_} foreach grep { exists $fdata->{$_} } keys %form;
        } else {
            _utf8_on($form{$_} = $self->req->param($_)) foreach $self->req->params();
        }
    }
    
    return
        blok => $blok,
        form => \%form,
        ferror => $self->FormError(),
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

sub adding :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('blok_edit_all') || return;
    $self->view_can_edit() || return;
    $self->template("blok_add");
    
    # Автозаполнение полей, если данные из формы не приходили
    my $form =
        { map { ($_ => '') } qw/name/ };
    if ($self->req->params()) {
        # Данные из формы - либо после ParamParse, либо напрямую данные
        my $fdata = $self->ParamData(fillall => 1);
        if (keys %$fdata) {
            $form->{$_} = $fdata->{$_} foreach grep { exists $fdata->{$_} } keys %$form;
        } else {
            _utf8_on($form->{$_} = $self->req->param($_)) foreach $self->req->params();
        }
    }
    return
        form => $form,
        ferror => $self->FormError(),
}

sub _logo {
    my ($self, $dirUpload, $blid) = @_;
    
    # Загрузка логотипа
    if (my $file = $self->req->param("photo")) {
        Func::MakeCachDir('blok', $blid)
            || return 900102;
        my $photo = Func::ImgCopy($self, "$dirUpload/$file", Func::CachDir('blok', $blid), 'logo')
            || return 900102;
        $self->model('Blok')->update(
            { 
                regen   => (1<<($::regen{logo}-1)),
                photo   => $photo,
            },
            { id => $blid }
        ) || return 000104;
        unlink("$dirUpload/$file");
    }
    
    return;
}

sub add :
    ReturnOperation
{
    my ($self) = @_;
    
    $self->rcheck('blok_edit_all') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    
    my $dirUpload = Func::SetTmpDir($self)
        || return ( error => 900101, pref => 'blok/adding' );
    
    # Проверяем данные из формы
    $self->ParamParse(model => 'Blok', is_create => 1, utf8 => 1)
        || return (error => 000101, pref => 'blok/adding', upar => $self->ParamData);
    
    # Сохраняем данные
    my $blid;
    $self->ParamSave( 
        model   => 'Blok', 
        insert  => \$blid,
    ) || return (error => 000104, pref => 'blok/adding', upar => $self->ParamData);
    
    # Загрузка логотипа
    my $err = _logo($self, $dirUpload, $blid);
    return (error => $err, pref => ['blok/edit', $blid]) if $err;
    
    return (ok => 970100, pref => ['blok/info', $blid]);
}

sub set :
    ParamObj('blok', 0)
    ReturnOperation
{
    my ($self, $blok) = @_;
    
    $self->rcheck('blok_edit') || return $self->rdenied;
    if (!$self->user->{blkid} || ($blok && ($self->user->{blkid} != $blok->{id}))) {
        $self->rcheck('blok_edit_all') || return $self->rdenied;
    }
    $self->d->{read_only} && return $self->cantedit();
    $blok || return $self->nfound();
    
    my $dirUpload = Func::SetTmpDir($self)
        || return ( error => 900101, pref => ['blok/edit', $blok->{id}] );
    
    # Проверяем данные из формы
    $self->ParamParse(model => 'Blok', utf8 => 1)
        || return (error => 000101, pref => ['blok/edit', $blok->{id}], upar => $self->ParamData);
    
    # Сохраняем данные
    $self->ParamSave( 
        model       => 'Blok', 
        update      => { id => $blok->{id} }, 
        preselect   => $blok
    ) || return (error => 000104, pref => ['blok/edit', $blok->{id}], upar => $self->ParamData);
    
    # Загрузка логотипа
    my $err = _logo($self, $dirUpload, $blok->{id});
    return (error => $err, pref => ['blok/edit', $blok->{id}]) if $err;
    
    # Статус с редиректом
    return (ok => 970200, pref => ['blok/info', $blok->{id}]);
}

sub del :
    ParamObj('blok', 0)
    ReturnOperation
{
    my ($self, $blok) = @_;
    
    $self->rcheck('blok_edit_all') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $blok || return $self->nfound();
    
    $self->model('Blok')->delete({ id => $blok->{id} })
        || return (error => 000104, href => '');
        
    # Убираем блок у команд
    $self->model('Command')->update(
        { blkid => 0 },
        { blkid => $blok->{id} },
    ) || return (error => 000104, href => '');
    
    # Убираем блок у аусвайсов
    $self->model('Ausweis')->update(
        { blkid => 0 },
        { blkid => $blok->{id} },
    ) || return (error => 000104, href => '');
    
    # статус с редиректом
    return (ok => 970300, pref => 'blok/list');
}



1;

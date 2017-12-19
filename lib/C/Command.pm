package C::Command;

use strict;
use warnings;

use Clib::Rights;

use Encode '_utf8_on', 'encode';

##################################################
###     Список команд
###     Код модуля: 98
#############################################

=pod
sub _item {
    my $self = shift;

    my $blok    = delete $_[0]->{blok};
    
    my $item = $self->d->{excel} ? shift : $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    $item->{blok}    = C::Blok::_item($self, $blok)
        if $blok;
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{CommandShow}, $item->{id}, 'info');
        $item->{href_srch}      = $self->href($::disp{AusweisList}."?cmdid=%d", $item->{id});
        $item->{href_edit}      = $self->href($::disp{CommandShow}, $item->{id}, 'edit');
        $item->{href_del}       = $self->href($::disp{CommandDel}, $item->{id});
        $item->{href_delete}    = $self->href($::disp{CommandDel}, $item->{id});
        $item->{href_history}   = $self->href($::disp{CommandHistory}, $item->{id});
        $item->{href_event_list}= $self->href($::disp{CommandEventList}, $item->{id});
        
        $item->{href_file}      = sub { $self->href($::disp{CommandFile}, $item->{id}, shift) };
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('command', $item->{id})."/$file";
        };
        
        $item->{href_aus_adding}= $self->href($::disp{AusweisAdding}."?cmdid=%d", $id);
        
        Func::regen_stat($self, $item);
    }
    
    return $item;
}

sub _list {
    my $self = shift;
    return $self->d->{cmd}->{_list} ||= [
        map { _item($self, $_); }
        $self->model('Command')->search({},{order_by=>'name'})
    ];
}

sub _hash {
    my $self = shift;
    return $self->d->{cmd}->{_hash} ||= {
        map { ($_->{id} => $_) }
        @{ _list($self) }
    };
}
=cut

sub list :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('command_list') || return;
    $self->template("command_list", 'CONTENT_result');
    
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
    
    my $blkid = $self->req->param_dig('blkid');
    push @qsrch, { f => 'blkid', val => $blkid };
    my $blok;
    if ($blkid) {
        $srch->{blkid} = $blkid > 0 ? $blkid : 0;
        if ($blkid > 0) {
            $blok = $self->model('Blok')->byId($blkid);
        }
    }
    
    my ($count, $countall);
    my @list = $self->model('Command')->search(
            $srch,
            {
                prefetch => 'blok',
                order_by => 'name',
            },
            pager => {
                onpage => 100,
                handler => sub {
                    my %p = @_;
                    $count = $p{count};
                    $countall = $p{countall};
                },
            },
        );
    
    return
        srch    => $s,
        qsrch => $self->qsrch(@qsrch),
        blkid   => $blkid,
        blok    => $blok,
        list    => \@list,
        count   => $count,
        countall=> $countall,
}

sub info :
    ParamObj('cmd', 0)
    ReturnPatt
{
    my ($self, $cmd) = @_;

    $self->view_rcheck('command_info') || return;
    $cmd || return $self->notfound;
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmd->{id})) {
        $self->view_rcheck('command_info_all') || return;
    }
    $self->template("command_info");
    
    my $filelogo = 'logo.site.jpg';
    my $flsize = -s Func::CachDir('command', $cmd->{id})."/$filelogo";
    
    my $blok;
    $blok = $self->model('Blok')->byId($cmd->{blkid}) if $cmd->{blkid};
    
    my @ausweis_list =
        $self->model('Ausweis')->search(
            { cmdid => $cmd->{id}, blocked => 0 },
            {
                order_by => 'nick',
            },
        );
    my @ausweis_blocked_list =
        $self->model('Ausweis')->search(
            { cmdid => $cmd->{id}, blocked => 1 },
            {
                order_by => 'nick',
            },
        );
    
    my @ausweis_preedit_list =
        map { 
            $_->{allow_cancel} = 1;
            #    $self->rights_check($::rPreeditCancel, $::rAll) ? 1 : (
            #        $self->rights_check($::rPreeditCancel, $::rMy) ?
            #            ($_->{uid} == $self->user->{id} ? 1 : 0) : 0
            #    );
            #$p->{href_show} = $self->href($::disp{CommandHistory}.'#pre%d', $rec->{id}, $p->{id});
            #$p->{href_cancel} = $self->href($::disp{PreeditCancel}, $p->{id});
            $_;
        }
        $self->model('Preedit')->search({
            tbl     => 'Ausweis',
            modered => 0,
            'field_cmdid.value' => $cmd->{id},
        }, {
            prefetch => ['field_cmdid', 'field_nick'],
            order_by => 'field_nick.value',
        });
    
    my @cmd_account_list =
        $self->model('UserList')->search({
            cmdid   => $cmd->{id},
        }, {
            prefetch => 'group',
            order_by => 'login',
        });
    
    my @ausweis_history_my = 
        map {
            $_->{nick} = $_->{ausweis}->{nick} || $_->{field_nick}->{value} || '';
            $_;
        }
        $self->model('Preedit')->search({
            uid     => $self->user->{id},
            tbl     => 'Ausweis',
            modered => { '!=' => 0 },
            visibled=> 1,
            -or     => { 'field_cmdid.value' => $cmd->{id}, 'ausweis.cmdid' => $cmd->{id} },
        }, {
            prefetch => [qw/field_cmdid field_nick ausweis/],
            order_by => 'id',
        });
    
    return
        cmd => $cmd,
        file_logo => $filelogo,
        file_logo_size => $flsize,
        blok => $blok,
        
        ausweis_list => \@ausweis_list,
        ausweis_preedit_list => \@ausweis_preedit_list,
        ausweis_blocked_list => \@ausweis_blocked_list,
        
        cmd_account_list => \@cmd_account_list,
        ausweis_history_my => \@ausweis_history_my,
}

sub my :
    ReturnPatt
{
    my ($self) = @_;
    
    my $user = $self->user || return $self->rdenied;
    my $cmdid = $self->user->{cmdid} || return $self->notfound;
    my $cmd = $self->obj(cmd => [$cmdid]) || return $self->notfound;
    
    return info($self, $cmd->{$cmdid});
}



sub history :
    ParamObj('cmd', 0)
    ReturnPatt
{
    my ($self, $cmd) = @_;

    $self->view_rcheck('command_info') || return;
    $cmd || return $self->notfound;
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmd->{id})) {
        $self->view_rcheck('command_info_all') || return;
    }
    $self->template("command_history");
    
    my $blok;
    $blok = $self->model('Blok')->byId($cmd->{blkid}) if $cmd->{blkid};
    
    # id затрагиваемых аусвайсов
    my %ausid = (map { ($_->{id}=>1) } $self->model('Ausweis')->search({ cmdid=>$cmd->{id} }));
    # id preedit на создание аусвайса
    my %eid_create = (
        map { ($_->{eid}=>1) } 
        $self->model('PreeditField')->search(
            { param => 'cmdid', value => $cmd->{id}, 'edit.op' => 'C', 'edit.tbl' => 'Ausweis' },
            { join => 'edit' }
        )
    );
        
    my %eid;
    my @list;
    if (%eid_create || %ausid) {
        push @list,
            map {
                $eid{$_->{id}}=$_;
                $_->{field_list} = [];
                $_->{allow_cancel} = 1;
                    #$self->rights_check($::rPreeditCancel, $::rAll) ? 1 : (
                    #    $self->rights_check($::rPreeditCancel, $::rMy) ?
                    #        ($_->{uid} == $self->user->{id} ? 1 : 0) : 0
                    #);
                $_;
            }
            $self->model('Preedit')->search([
                    %eid_create ? { id => [keys %eid_create] } : (),
                    %ausid ? { tbl=>'Ausweis', recid=>[keys %ausid] } : ()
                ], {
                    prefetch    => ['user', 'ausweis'],
                    order_by    => 'id'
                });
    }
    if (%eid) {
        push( @{ $eid{$_->{eid}}->{field_list} }, $_)
            foreach 
                map { $_->{enold} = defined $_->{old}; $_ }
                $self->model('PreeditField')->search(
                    { eid => [keys %eid] }, 
                    { order_by => 'field' }
                );
    }
    
    return
        cmd => $cmd,
        blok => $blok,
        list => \@list,
}


sub event :
    ParamObj('cmd', 0)
    ReturnPatt
{
    my ($self, $cmd) = @_;

    $self->view_rcheck('command_info') || return;
    $cmd || return $self->notfound;
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmd->{id})) {
        $self->view_rcheck('command_info_all') || return;
    }
    $self->template("command_event");
    
    my $blok;
    $blok = $self->model('Blok')->byId($cmd->{blkid}) if $cmd->{blkid};
    
    my %ev;
    my @event =
        $self->model('Event')->search(
            {},
            { order_by => '-date', },
        );
    my %year = ();
    my @year;
    my $hidden = 0;
    foreach my $ev (@event) {
        $ev->{ausweis_list} = [];
        $ev{$ev->{id}} = $ev;
        my ($year) = ($ev->{date} =~ /^(\d{4})\-/);
        $year ||= '-';
        my $y = $year{$year};
        if (!$y) {
            $y = ($year{$year} = { year => $year, list => [], hidden => $hidden++ });
            push @year, $y;
        }
        push @{ $y->{list} }, $ev;
    }
        
    push(@{ $ev{ $_->{event}->{evid} }->{ausweis_list} }, $_)
        foreach
            $self->model('Ausweis')->search({
                'event.cmdid' => $cmd->{id}
            }, {
                prefetch => [qw/event command/],
                #order_by => 'nick'
                order_by => 'event.dtadd'
            });
    
    return
        cmd => $cmd,
        blok => $blok,
        event_list => \@event,
        year_list => \@year,
}


sub edit :
    ParamObj('cmd', 0)
    ReturnPatt
{
    my ($self, $cmd) = @_;

    $self->view_rcheck('command_edit') || return;
    $cmd || return $self->notfound;
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmd->{id})) {
        $self->view_rcheck('command_edit_all') || return;
    }
    $self->view_can_edit() || return;
    $self->template("command_edit");
    
    my %form = %$cmd;
    if ($self->req->params() && (my $fdata = $self->ParamData)) {
        if (keys %$fdata) {
            $form{$_} = $fdata->{$_} foreach grep { exists $fdata->{$_} } keys %form;
        } else {
            _utf8_on($form{$_} = $self->req->param($_)) foreach $self->req->params();
        }
    }
    
    return
        cmd => $cmd,
        form => \%form,
        ferror => $self->FormError(),
        blok_list => [ $self->model('Blok')->search({},{order_by=>'name'}) ],
        ausweis_list_size => $self->model('Ausweis')->count({ cmdid => $cmd->{id} }),
}

sub file :
    ParamObj('cmd', 0)
    ParamRegexp('[a-zA-Z\d\.\-]+')
    ReturnPatt
{
    my ($self, $cmd, $file) = @_;

    $self->view_rcheck('command_file') || return;
    $cmd || return $self->notfound;
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmd->{id})) {
        $self->view_rcheck('command_file_all') || return;
    }
    my $d = $self->d;
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('command', $cmd->{id})."/$file";
    
    if (my $t = $::CommandFile{$file}) {
        $d->{type} = $t->[0]||'';
        my $m = Clib::Mould->new();
        $d->{filename} = $m->Parse(data => $t->[1]||'', pattlist => $cmd, dot2hash => 1);
    }
}

sub adding :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('command_edit_all') || return;
    $self->view_can_edit() || return;
    $self->template("command_add");
    
    # Автозаполнение полей, если данные из формы не приходили
    my $form =
        { map { ($_ => '') } qw/name blkid login pass/ };
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
        blok_list => [ $self->model('Blok')->search({},{order_by=>'name'}) ],
}

sub _logo {
    my ($self, $dirUpload, $cmdid) = @_;
    
    # Загрузка логотипа
    if (my $file = $self->req->param("photo")) {
        Func::MakeCachDir('command', $cmdid)
            || return 900102;
        my $photo = Func::ImgCopy($self, "$dirUpload/$file", Func::CachDir('command', $cmdid), 'logo')
            || return 900102;
        $self->model('Command')->update(
            { 
                regen   => (1<<($::regen{logo}-1)),
                photo   => $photo,
            },
            { id => $cmdid }
        ) || return 000104;
        unlink("$dirUpload/$file");
    }
    
    return;
}

sub add :
    ReturnOperation
{
    my ($self) = @_;
    
    $self->rcheck('command_edit_all') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    
    my $dirUpload = Func::SetTmpDir($self)
        || return ( error => 900101, pref => 'command/adding' );
    
    my %err = ();
    my %new = ();
    my $q = $self->req;
    
    foreach my $p (qw/name login/) {
        _utf8_on($new{$p} = $q->param_str($p))
            if defined $q->param($p);
    }
    foreach my $p (qw/pass/) {
        _utf8_on($new{$p} = $q->param($p))
            if defined $q->param($p);
    }
    foreach my $p (qw/blkid/) {
        $new{$p} = $q->param_int($p)
            if defined $q->param($p);
    }
    
    my %adm =
        map { ($_ => delete $new{$_}) }
        grep { exists $new{$_} }
        qw/login pass/;
    
    # Проверка данных
    if ($new{name}) {
        if ($self->model('Command')->count({ name => $new{name} })) {
            $err{name} = 13;
        }
    }
    else {
        $err{name} = 1;
    }
    
    if ($new{blkid}) {
        if (!$self->model('Blok')->byId($new{blkid})) {
            $err{blkid} = 11;
        }
    }
    
    if (exists($adm{login}) && ($adm{login} ne '')) {
        $adm{gid} = $self->c('command_gid');
        if ($adm{login} !~ /^[a-zA-Z_0-9\-а-яА-Я]+$/) {
            $err{login} = 2;
        }
        elsif ($self->model('UserList')->count({ login => $adm{login} })) {
            $err{login} = 14;
        }
        elsif (!$adm{gid} || !$self->model('UserGroup')->byId($adm{gid})) {
            $err{login} = 15;
        }
    }
    else {
        %adm = ();
    }
    
    if (exists($adm{pass})) {
        if ($adm{pass} eq '') {
            $err{pass} = 1;
        }
        else {
            $adm{password} = { PASSWORD => delete $adm{pass} };
        }
    }
    
    # Ошибки заполнения формы
    my @fpar = (qw/name blkid login pass/);
    if (%err) {
        return (error => 000101, pref => 'command/adding', fpar => \@fpar, ferr => \%err);
    }
    
    # Сохраняем данные
    $self->model('Command')->create(\%new)
        || return (error => 000104, pref => 'command/adding', fpar => \@fpar, ferr => {});
    my $cmdid = $self->model('Command')->insertid();
    
    # Создаем аккаунт
    if (%adm) {
        $adm{rights} = RIGHT_GROUP x 128;
        $adm{cmdid} = $cmdid;
        $self->model('UserList')->create(\%adm)
            || return (error => 000104, pref => 'command/adding', fpar => \@fpar, ferr => {});
    }
    
    # Загрузка логотипа
    my $err = _logo($self, $dirUpload, $cmdid);
    return (error => $err, pref => ['command/edit', $cmdid]) if $err;
    
    return (ok => 980100, pref => ['command/info', $cmdid]);
}


sub set :
    ParamObj('cmd', 0)
    ReturnOperation
{
    my ($self, $cmd) = @_;
    
    $self->rcheck('command_edit') || return $self->rdenied;
    if (!$self->user->{cmdid} || ($cmd && ($self->user->{cmdid} != $cmd->{id}))) {
        $self->rcheck('command_edit_all') || return $self->rdenied;
    }
    $self->d->{read_only} && return $self->cantedit();
    $cmd || return $self->nfound();
    
    my $dirUpload = Func::SetTmpDir($self)
        || return ( error => 900101, pref => ['command/edit', $cmd->{id}] );
    
    # Проверяем данные из формы
    $self->ParamParse(model => 'Command', utf8 => 1)
        || return (error => 000101, pref => ['command/edit', $cmd->{id}], upar => $self->ParamData);
    
    # Сохраняем данные
    $self->ParamSave( 
        model       => 'Command', 
        update      => { id => $cmd->{id} }, 
        preselect   => $cmd
    ) || return (error => 000104, pref => ['command/edit', $cmd->{id}], upar => $self->ParamData);
    
    # Загрузка логотипа
    my $err = _logo($self, $dirUpload, $cmd->{id});
    return (error => $err, pref => ['command/edit', $cmd->{id}]) if $err;
    
    # Обновляем blkid у аусвайсов
    my $fdata = $self->ParamData;
    if (defined($fdata->{blkid}) && ($fdata->{blkid} != $cmd->{blkid})) {
        $self->model('Ausweis')->update(
            { blkid => $fdata->{blkid} },
            { cmdid => $cmd->{id} }
        ) || return (error => 000104, pref => ['command/info', $cmd->{id}]);
    }
    
    # Статус с редиректом
    return (ok => 980200, pref => ['command/info', $cmd->{id}]);
}


sub logo :
    ParamObj('cmd', 0)
    ReturnOperation
{
    my ($self, $cmd) = @_;
    
    $self->rcheck('command_edit') || return $self->rdenied;
    if (!$self->user->{cmdid} || ($cmd && ($self->user->{cmdid} != $cmd->{id}))) {
        $self->rcheck('command_edit_all') || return $self->rdenied;
    }
    $cmd || return $self->nfound();
    
    my $dirUpload = Func::SetTmpDir($self)
        || return ( error => 900101, pref => ['command/info', $cmd->{id}] );
    
    # Загрузка логотипа
    my $err = _logo($self, $dirUpload, $cmd->{id});
    return (error => $err, pref => ['command/info', $cmd->{id}]) if $err;
    
    # Статус с редиректом
    return (ok => 980200, pref => ['command/info', $cmd->{id}]);
}

sub del :
    ParamObj('cmd', 0)
    ReturnOperation
{
    my ($self, $cmd) = @_;
    
    $self->rcheck('command_edit_all') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $cmd || return $self->nfound();
    
    my ($item) = $self->model('Ausweis')->search({ cmdid => $cmd->{id} }, { limit => 1 });
    return (error => 980301, href => '') if $item;
    
    $self->model('Command')->delete({ id => $cmd->{id} })
        || return (error => 000104, href => '');
    
    # статус с редиректом
    return (ok => 980300, pref => 'command/list');
}
    
1;

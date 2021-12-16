package CMain::Command;

use Clib::strict8;

##################################################

sub by_id {
    sqlGet(command => shift());
}

sub rinfo {
    my $cmd = shift();
    
    rchk('command_info') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{cmdid} || ($cmd && ($user->{cmdid} != $cmd->{id}))) {
        rchk('command_info_all') || return;
    }
    
    1;
}

sub redit {
    my $cmd = shift();
    
    rchk('command_edit') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{cmdid} || ($cmd && ($user->{cmdid} != $cmd->{id}))) {
        rchk('command_edit_all') || return;
    }
    
    1;
}

sub _root :
        Simple
{
    rchk('command_list') || return 'rdenied';
    my $p = wparam();
    
    my @query = ();
    my @where = ();
    
    if ($p->exists('srch') && length($p->str('srch'))) {
        my $s = $p->str('srch');
        
        push @query, srch => $s;
        
        $s =~ s/([%_])/\\$1/g;
        $s =~ s/\*/%/g;
        $s =~ s/\?/_/g;
        $s = '%'.$s if $s !~ /^%/;
        $s .= '%' if $s !~ /%$/;
        #$s .= '%' if $s !~ /^(.*[^\\])?%$/;
        push @where, sqlLike(name => $s);
    }

    my ($blkid, $blok);
    if ($p->exists('blkid')) {
        $blkid = $p->int('blkid');
        
        push @query, blkid => $blkid;
        push @where, blkid => $blkid > 0 ? $blkid : 0;
        
        $blok = sqlGet(blok => $blkid);
    }
    
    my $pager = { onpage => 100 };
    my @list = sqlSrch(command => @where, $pager, sqlOrder('name'));
    
    my %blk =
        map {
            $_->{blkid} > 0 ?
                ($_->{blkid} => 1) : ()
        }
        @list;
    if (my @blkid = keys %blk) {
        %blk =
            map { ($_->{id} => $_) }
            sqlSrch(blok => id => @blkid > 1 ? [@blkid] : $blkid[0]);
        $_->{blok} = $blk{$_->{blkid}} foreach @list;
    }
    
    return
        'command_list',
        srch    => $p->str('srch'),
        qsrch   => qsrch([qw/srch/], @query),
        blkid   => $blkid,
        blok    => $blok,
        list    => \@list,
        pager   => $pager;
}

sub srch :
        ReturnBlock
{
    my ($tmpl, @p) = _root();
    return
        $tmpl => 'CONTENT_result',
        @p;
}

sub info :
        ParamCodeUInt(\&by_id)
{
    my $cmd = shift();
    
    rinfo($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    
    my $filelogo = 'logo.site.jpg';
    my $filesize = -s ImgFile::CachPath(command => $cmd->{id}, $filelogo);
    
    my $blok = $cmd->{blkid} ?
        sqlGet(blok => $cmd->{blkid}) :
        undef;
    
    my @ausweis_list =
        sqlSrch(
            ausweis =>
            cmdid   => $cmd->{id},
            blocked => 0,
            sqlOrder('nick')
        );
    
    my @ausweis_blocked =
        sqlSrch(
            ausweis =>
            cmdid   => $cmd->{id},
            blocked => 1,
            sqlOrder('nick')
        );
    
    # Ник для preedit-записей
    my $prenick = sub {
        if (my @precreate = grep { $_->{op} eq 'C' } @_) {
            # Для создаваемых аусов ник берём из preedit_field
            my %nick =
                map { ($_->{eid} => $_->{value}) }
                sqlSrch(
                    preedit_field =>
                    eid     => [map { $_->{id} } @precreate],
                    param   => 'nick',
                );
            $_->{nick} = $nick{ $_->{id} } foreach @precreate;
        }
        if (my @preedit = grep { $_->{op} eq 'E' } @_) {
            # для редактируемых - они скорее всего не из нашей команды,
            # раз есть поле cmdid, и их ники надо взять из аусов
            my %nick =
                map { ($_->{id} => $_->{nick}) }
                sqlSrch(ausweis => id => [map { $_->{recid} } @preedit]);
            $_->{nick} = $nick{ $_->{recid} } foreach @preedit;
        }
    };
    
    # аусы, ожидающие добавление или перенос в нашу команду:
    # тут действуем по изменению поля cmdid, указанного в preedit_field
    my @ausweis_preedit =
        map { $_->{preedit} }
        sqlQueryList(
            'SELECT `preedit`.* FROM `preedit`, `preedit_field` ' .
                'WHERE `preedit_field`.`eid`=`preedit`.`id` ' .
                    'AND `preedit`.`tbl`=\'Ausweis\' ' .
                    'AND `preedit`.`modered`=0 ' .
                    'AND `preedit`.`uid`=? ' .
                    'AND `preedit_field`.`param`=\'cmdid\' ' .
                    'AND `preedit_field`.`value`=?',
            (WebMain::auth('user')||{})->{id},
            $cmd->{id}
        );
    $prenick->(@ausweis_preedit);
    
    # Аусы, прошедшие модерацию, но только для текущего аккаунта (так проще запрашивать)
    # Но надо бы переделать, чтобы тут отображались все редактируемые аусы, имеющие отношение
    # к нашей команде
    # Для этого надо добавить поля cmdid и cmdold(на случай переноса в другую команду),
    # корректно их заполнять, и запрашивать preedit уже по этим полям
    my @history_my =
        sqlSrch(
            preedit =>
            tbl     => 'Ausweis',
            sqlNotEq(modered => 0),
            uid     => (WebMain::auth('user')||{})->{id},
            visibled=> 1,
            sqlGt(dtadd => Clib::DT::fromtime(time()-3600*24*30)),
            sqlOrder('id'),
        );
    $prenick->(@history_my);
    
    my @account_list =
        sqlSrch(user_list => cmdid => $cmd->{id}, sqlOrder('login'));
    my %grp =
        map { $_->{gid} > 0 ? ($_->{gid} => 1) : () }
        @account_list;
    if (my @gid = keys %grp) {
        %grp =
            map { ($_->{id} => $_) }
            sqlSrch(user_group => id => \@gid);
        $_->{group} = $grp{ $_->{gid} }
            foreach @account_list;
    }
    
    return
        'command_info',
        cmd             => $cmd,
        file_logo       => $filelogo,
        file_logo_size  => $filesize,
        blok            => $blok,
        
        ausweis_list    => \@ausweis_list,
        ausweis_preedit => \@ausweis_preedit,
        ausweis_blocked => \@ausweis_blocked,
        
        account_list    => \@account_list,
        history_my      => \@history_my,
}

sub my :
        Simple
{
    my $user = WebMain::auth('user') || return 'rdenied';
    my $cmdid = $user->{cmdid} || return 'notfound';
    my $cmd = by_id($cmdid) || return 'notfound';
    
    return info($cmd);
}



=pod
sub history :
        ParamCodeUInt(\&by_id)
{
    my $cmd = shift();
    
    rinfo($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    
    my $blok = $cmd->{blkid} ?
        sqlGet(blok => $cmd->{blkid}) :
        undef;
    
    # id затрагиваемых аусвайсов
    my %ausid = 
        map { ($_->{id} => 1) }
        sqlSrch(ausweis => cmdid=>$cmd->{id} );
    
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
        'command_history'
        cmd     => $cmd,
        blok    => $blok,
        list    => \@list,
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
    
    $self->rcheck('command_logo') || return $self->rdenied;
    if (!$self->user->{cmdid} || ($cmd && ($self->user->{cmdid} != $cmd->{id}))) {
        $self->rcheck('command_logo_all') || return $self->rdenied;
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
    return (ok => 980300, pref => 'command');
}
=cut
    
1;

package CMain::Ausweis;

use Clib::strict8;

##################################################

sub by_id {
    sqlGet(ausweis => shift());
}

sub rinfo {
    my $cmdid = shift() || 0;
    
    rchk('ausweis_info') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{cmdid} || ($user->{cmdid} != $cmdid)) {
        rchk('ausweis_info_all') || return;
    }
    
    1;
}

sub redit {
    my $cmdid = shift() || 0;
    
    rchk('ausweis_edit') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{cmdid} || ($user->{cmdid} != $cmdid)) {
        rchk('ausweis_edit_all') || return;
    }
    
    1;
}

sub prefield {
    my $aus = shift();
    
    # Премодерация изменений
    my @pre =
        sqlSrch(
            preedit =>
            tbl     => 'Ausweis',
            op      => 'E',
            recid   => $aus->{id},
            modered => 0
        );
    @pre || return;
    
    return
        map { ($_->{param} => $_) }
        sqlSrch(preedit_field => eid => [map { $_->{id} } @pre]);
}

sub gennumid {
    my $max = sqlMax(ausweis => 'numid') || return;
    return return $max+1;
}

sub _root :
        Simple
{
    rchk('ausweis_list') || return 'rdenied';
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
        push @where, sqlOr(map { sqlLike($_ => $s) } qw/nick fio comment krov allerg neperenos polis medik/);
    }
    
    my $numidnick;
    if ($p->exists('numidnick')) {
        $numidnick = $p->str('numidnick');
        
        push @query, numidnick => $numidnick;
        
        if ($numidnick =~ /^\d{10}$/) {
            push @where, numid => $numidnick;
        }
        elsif ($numidnick ne '') {
            $numidnick =~ s/([%_])/\\$1/g;
            $numidnick =~ s/\*/%/g;
            $numidnick =~ s/\?/_/g;
            push @where, sqlLike(nick => $numidnick);
        }
    }

    my ($blkid, $blok);
    if ($p->exists('blkid')) {
        $blkid = $p->uint('blkid');
        
        push @query, blkid => $blkid;
        
        push @where, blkid => $blkid;
        if ($blkid > 0) {
            $blok = sqlGet(blok => $blkid);
        }
    }

    my ($cmdid, $cmd);
    if ($p->exists('cmdid')) {
        $cmdid = $p->uint('cmdid');
        
        push @query, cmdid => $cmdid;
        
        push @where, cmdid => $cmdid;
        if ($cmdid > 0) {
            $cmd = sqlGet(command => $cmdid);
        }
    }
    
    # Получения списка
    my $pager = { onpage => 100 };
    my @list = sqlSrch(ausweis => @where, $pager, sqlOrder('nick'));
    
    if ($p->exists('numidnick') && (@list == 1)) {
        #info(@list);
    }
    
    # команды
    my %cmd = map { ($_->{cmdid} => 1) } @list;
    if (%cmd) {
        %cmd =
            map { ($_->{id} => $_) }
            sqlGet(command => [keys %cmd]);
    }
    
    # блоки
    my %blk = map { $_->{blkid} ? ($_->{blkid} => 1) : () } @list;
    if (%blk) {
        %blk =
            map { ($_->{id} => $_) }
            sqlGet(blok => [keys %blk]);
    }
    
    foreach my $aus (@list) {
        $aus->{command} = $cmd{ $aus->{cmdid} };
        $aus->{blok} = $blk{ $aus->{blkid} };
    }
    
    return
        'ausweis_list',
        srch    => $p->str('srch'),
        qsrch   => qsrch([qw/srch numidnick blkid cmdid/], @query),
        numidnick => $numidnick,
        blkid   => $blkid,
        blok    => $blok,
        cmdid   => $cmdid,
        cmd     => $cmd,
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
    my $aus = shift();
    
    rinfo($aus->{cmdid}) || return 'rdenied';
    $aus || return 'notfound';
    
    my $cdir = join '/', ImgFile::CachDir(ausweis => $aus->{id});
    my @file =
        map {
            'file_'.$_->[0]         => $_->[1],
            'file_'.$_->[0].'_size' => -s $cdir.'/'.$_->[1]
        }
        (
            [photo => 'photo.site.jpg'],
            [front => 'print.front.jpg'],
            [rear  => 'print.rear.jpg'],
            [pdf   => 'print.pdf'],
        );
    
    my $blok = $aus->{blkid} ?
        sqlGet(blok => $aus->{blkid}) :
        undef;
    
    my $cmd = sqlGet(command => $aus->{cmdid});
    
    # Премодерация изменений
    my %prefield = prefield($aus);
    
    # Участие в мероприятиях
    my @evaus = sqlSrch(event_ausweis => ausid => $aus->{id});
    my @event;
    if (@evaus) {
        my %cmd = map { ($_->{cmdid} => 1) } @evaus;
        %cmd = map { ($_->{id} => $_) } sqlGet(command => [keys %cmd]);
        my %ev = map { ($_->{evid} => $_) } @evaus;
        @event =
            map {
                if (my $ev = $ev{$_->{id}}) {
                    $_->{cmdid} = $ev->{cmdid};
                    $_->{command} = $cmd{ $ev->{cmdid} };
                    $_;
                }
                else {
                    ();
                }
            }
            sqlSrch(event => id => [keys %ev], sqlOrder('date'));
    }
    
    return
        'ausweis_info',
        aus     => $aus,
        @file,
        file => { @file },
        blok    => $blok,
        cmd     => $cmd,
        prefield=> \%prefield,
        event   => \@event,
}


=pod
# Оставим пока тут обрезки старого функционала для прохождения КПП
sub show {
    my ($self, $id, $type) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    my $d = $self->d;
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);
    
    $type = 'event' if ($type eq 'info') && $d->{event}->{view};
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id }, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105);
    $d->{form} = $rec;
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $rec->{cmdid})) {
        return unless $self->rights_check_event($::rAusweisInfo, $::rAll);
    }
    
    $self->patt(TITLE => sprintf($text::titles{"ausweis_$type"}, $rec->{nick}));
    $self->view_select->subtemplate("ausweis_$type.tt");
    
    if ($type eq 'edit') {
        return unless 
            $self->rights_exists($::rAusweisEdit) ||
            $self->rights_exists_event($::rAusweisPreEdit);
        if (!$self->user->{cmdid} || ($self->user->{cmdid} != $rec->{cmdid})) {
            return unless
                $self->rights_check($::rAusweisEdit, $::rAll) ||
                $self->rights_check_event($::rAusweisPreEdit, $::rAll);
        }
        $self->can_edit() || return;
    }
    
    $d->{href_set} = $self->href($::disp{AusweisSet}, $id);
    
    # Партия на печать
    $d->{print_list} = sub {
        return $d->{_print_list} ||= [
            map { C::Print::_item($self, $_) }
            $self->model('Print')->search(
                { 'ausweis.ausid' => $rec->{id} },
                { join => 'ausweis', order_by => 'id' }
            )
        ];
    };
    $d->{print_open} = sub {
        return $d->{_print_open} if defined $d->{_print_open};
        ($d->{_print_open}) = 
            map { C::Print::_item($self, $_) } 
                $self->model('Print')->search(
                    { status => 'A' },
                    { order_by => '-id', limit => 1 }
                );
        return $d->{_print_open} ||= 0;
    };
    
    # Мероприятия
    $d->{allow_event} = $self->rights_exists($::rEvent);
    $d->{allow_event_commit} = $self->rights_check($::rEventCommit, $::rYes, $::rAdvanced);
    $d->{event_list} = sub {
        $d->{_event_list} ||= [
            map { 
                my $ev = C::Event::_item($self, $_, $rec->{cmdid});
                $ev->{commit} = sub {
                    if (!defined($ev->{_commit})) {
                        ($ev->{_commit}) = $self->model('EventAusweis')->search({ evid => $ev->{id}, ausid => $rec->{id} });
                        $ev->{_commit} ||= 0;
                    }
                    $ev->{_commit};
                };
                $ev->{href_ausweis_commit} = $self->href($::disp{EventAusweisCommit}, $ev->{id}, $rec->{id});
                $ev->{href_ausweis_decommit} = $self->href($::disp{EventAusweisDeCommit}, $ev->{id}, $rec->{id});
                $ev->{summ_avail} = sub {
                    my $list = $ev->{ausweis_list}->();
                    my $summ = 0;
                    $summ += $_->{event}->{price} 
                        foreach grep { !$_->{event}->{payonkpp} } @$list;
                    return sprintf('%0.2f', $ev->{money}->()->{summ}-$summ);
                };
                $ev->{allow_from_summ} = sub {
                    return $ev->{summ_avail}->() >= $ev->{money}->()->{price};
                };
                $ev->{summ_onkpp} = sub {
                    my $list = $ev->{ausweis_list}->();
                    my $summ = 0;
                    $summ += $_->{event}->{price} 
                        foreach grep { $_->{event}->{payonkpp} } @$list;
                    return sprintf('%0.2f', $summ);
                };
                $ev;
            }
            $self->model('Event')->search({
                status  => 'O',
            }, {
                order_by => [qw/date id/],
            })
        ];
    };
}
=cut


sub edit :
        ParamCodeUInt(\&by_id)
{
    my $aus = shift();
    
    redit($aus->{cmdid}) || return 'rdenied';
    $aus || return 'notfound';
    editable() || return 'readonly';
    
    # Премодерация изменений
    my %prefield = prefield($aus);
    
    my @blk = sqlAll(blok => 'name');
    my @cmd = sqlAll(command => 'name');
    
    return
        'ausweis_edit',
        aus         => $aus,
        form($aus),
        prefield    => \%prefield,
        blok_list   => \@blk,
        cmd_list    => \@cmd;
}

sub file :
        ParamCodeUInt(\&by_id)
        ParamRegexp('[a-zA-Z\d\.\-]+')
        ParamEnd # ссылку будет завершать не имя функции "file", а само имя файла из аргументов
        ReturnFile
{
    my $aus = shift();
    
    rinfo($aus->{cmdid}) || return 'rdenied';
    $aus || return 'notfound';
    
    return ImgFile::CachPath(ausweis => $aus->{id}, shift());
}

sub adding :
        Simple
{
    my $p = wparam();
    
    my $cmdid =
        $p->exists('cmdid') ?
            $p->uint('cmdid') :
            (WebMain::auth('user') || {})->{cmdid};
    
    redit($cmdid) || return 'rdenied';
    editable() || return 'readonly';
    
    my @form =
        form(
            $cmdid ? { cmdid => $cmdid } : (),
            qw/nick cmdid fio krov allerg neperenos polis medik comment/
        );
    
    my @blk = sqlAll(blok => 'name');
    my @cmd = sqlAll(command => 'name');
    
    return
        'ausweis_add',
        @form,
        blok_list   => \@blk,
        cmd_list    => \@cmd;
}

# Загрузка логотипа
sub _photo_load {
    my $ausid = shift();
    defined($_[0]) || return 1;
    my $regen = $_[1] || [];
    
    my $p = wparam();
    my $ext = $p->str('photo') =~ /\.([a-zA-Z0-9]{1,5})$/ ? lc($1) : 'jpg';
    my $fname = ImgFile::Save($_[0], [ausweis => $ausid], photo => orig => $ext)
        || return;
    
    sqlUpd(
        ausweis => $ausid,
        regen   => ImgFile::RegenBit(qw/photo print_img print_pdf/, @$regen),
        photo   => $fname
    ) || return;
    
    return 1;
}

sub add :
        ReturnOperation
{
    my $photo;
    my $p = wparam(file => { photo => \$photo });
    my $cmdid = $p->uint('cmdid');
    
    redit($cmdid) || return err => 'rdenied';
    editable() || return err => 'readonly';
    
    # Проверка данных
    my %err = ();
    my @new = ();
    
    if ($p->exists('nick')) {
        my $nick = $p->str('nick');
        push @new, nick => $nick;
        
        if ($nick eq '') {
            $err{nick} = 'empty';
        }
        else {
            my $blocked = $p->bool('blocked') ? 1 : 0;
            my @nick =
                sqlSrch(
                    ausweis =>
                    nick    => $nick,
                    cmdid   => $cmdid,
                    blocked => $blocked,
                );
            if (@nick) {
                $err{nick} = $blocked ? 'ausblockexs' : 'ausexists';
            }
        }
    }
    else {
        $err{nick} = 'nospec';
    }

    if ($cmdid != 0) {
        push @new, cmdid => $cmdid;
        my $cmd = sqlGet(command => $cmdid);
        if ($cmd) {
            push @new, blkid => $cmd->{blkid};
        }
        else {
            $err{cmdid} = 'cmdunknown';
        }
    }
    else {
        $err{cmdid} = 'nospec';
    }
    
    if ($p->exists('blocked')) {
        push @new, blocked => $p->bool('blocked') ? 1 : 0;
    }
    
    if ($p->exists('fio')) {
        my $fio = $p->str('fio');
        push @new, fio => $fio;
        
        if ($fio eq '') {
            $err{fio} = 'empty';
        }
        elsif (!$p->bool('blocked')) {
            my @fio =
                sqlSrch(
                    ausweis =>
                    fio     => $fio,
                    cmdid   => $cmdid,
                    blocked => 0,
                );
            $err{fio} = 'fioexists' if @fio;
        }
    }
    else {
        $err{fio} = 'nospec';
    }
    
    if (!defined($photo)) {
        $err{photo} = 'nophoto';
    }
    
    foreach my $f (qw/krov allerg neperenos polis medik comment/) {
        next if !$p->exists($f);
        my $v = $p->str($f);
        next if $v eq '';
        push @new, $f => $v;
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => 'ausweis/adding';
    }
    
    # numid
    if (my $numid = gennumid()) {
        unshift @new, numid => $numid;
        push @new, regen => ImgFile::RegenBit('code');
    }
    else {
        return
            err  => c(state => 'gennumid'),
            ferr => \%err,
            pref => 'ausweis/adding';
    }
    
    # Сохраняем
    
    my $pref;
    my $preid;
    my @preedit = (
        dtadd   => Clib::DT::now(),
        tbl     => 'Ausweis',
        op      => 'C',
        uid     => (WebMain::auth('user') || {})->{id} || 0,
        ip      => WebMain::auth('ip') || '',
    );
    my @prefld = @new;
    # Процесс сохранения зависит от того, какие у нас права - только премодерация или можно сразу сохранять
    if (rchk('ausweis_pree')) {
        $pref = ['command/info', $cmdid];
        
        # preedit - основная таблица
        $preid = sqlAdd(preedit => @preedit, modered => 0)
            || return err => 'db', pref => ['ausweis/adding'];
            
        # Загрузка фото
        my $ext = $p->str('photo') =~ /\.([a-zA-Z0-9]{1,5})$/ ? lc($1) : 'jpg';
        my $fname = ImgFile::Save($photo, [preedit => $preid], photo => orig => $ext)
            || return err => 'imgload', pref => $pref;
        
        push @prefld, photo => $fname;
    }
    else {
        # Добавляем в БД
        my $ausid = sqlAdd(ausweis => @new)
            || return
                err  => 'db',
                ferr => \%err,
                pref => 'ausweis/adding';
        
        $pref = ['ausweis/info', $ausid];
        
        # preedit - основная таблица
        $preid = sqlAdd(preedit => @preedit, recid => $ausid, modered => 1)
            || return err => 'db', pref => $pref;
            
        # Загрузка фото
        _photo_load($ausid, $photo, ['code'])
            || return
                err  => 'imgload',
                pref => ['ausweis/edit', $ausid];
    }
    
    while (@prefld && (my ($p, $v) = splice(@prefld, 0, 2))) {
        sqlAdd(
            preedit_field =>
            eid     => $preid,
            param   => $p,
            value   => $v
        ) || return err => 'db', pref => $pref;
    }
    
    return
        ok => 1,
        pref => $pref;
}

sub set :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $aus = shift();
    
    redit($aus->{cmdid}) || return err => 'rdenied';
    $aus || return err => 'notfound';
    editable() || return err => 'readonly';
    
    # Проверка данных
    my $photo;
    my $p = wparam(file => { photo => \$photo });
    my %err = ();
    my @upd = ();
    
    if ($p->exists('nick')) {
        my $nick = $p->str('nick');
        push(@upd, nick => $nick) if $nick ne $aus->{nick};
        
        if ($nick eq '') {
            $err{nick} = 'empty';
        }
        else {
            my $blocked = $p->bool('blocked') ? 1 : 0;
            my $cmdid = $p->exists('cmdid') ?
                $p->uint('cmdid') :
                $aus->{cmdid};
            my @nick =
                sqlSrch(
                    ausweis =>
                    sqlNotEq(id => $aus->{id}),
                    nick    => $nick,
                    cmdid   => $cmdid,
                    blocked => $blocked,
                );
            if (@nick) {
                $err{nick} = $blocked ? 'ausblockexs' : 'ausexists';
            }
        }
    }
    
    if ($p->exists('cmdid')) {
        my $cmdid = $p->uint('cmdid');
        push(@upd, cmdid => $cmdid) if $cmdid != $aus->{cmdid};
        my $cmd = sqlGet(command => $cmdid);
        if ($cmd) {
            push(@upd, blkid => $cmd->{blkid})
                if $cmd->{blkid} != $aus->{blkid};
        }
        else {
            $err{cmdid} = 'cmdunknown';
        }
    }
    
    if ($p->exists('blocked')) {
        my $blocked = $p->bool('blocked') ? 1 : 0;
        push(@upd, blocked => $blocked) if $blocked != $aus->{blocked};
    }
    
    if ($p->exists('fio')) {
        my $fio = $p->str('fio');
        push(@upd, fio => $fio) if $fio ne $aus->{fio};
        
        if ($fio eq '') {
            $err{fio} = 'empty';
        }
        elsif (!$p->bool('blocked')) {
            my $cmdid = $p->exists('cmdid') ?
                $p->uint('cmdid') :
                $aus->{cmdid};
            my @fio =
                sqlSrch(
                    ausweis =>
                    sqlNotEq(id => $aus->{id}),
                    fio     => $fio,
                    cmdid   => $cmdid,
                    blocked => 0,
                );
            $err{fio} = 'fioexists' if @fio;
        }
    }
    
    foreach my $f (qw/krov allerg neperenos polis medik comment/) {
        next if !$p->exists($f);
        my $v = $p->str($f);
        next if $v eq $aus->{$f};
        push @upd, $f => $v;
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => ['ausweis/edit' => $aus->{id}];
    }
    
    # Надо ли, что сохранять
    if (!@upd && !defined($photo)) {
        return err => 'nochange', pref => ['ausweis/edit' => $aus->{id}];
    }
    
    # Сохраняем
    
    my $preid;
    my @preedit = (
        dtadd   => Clib::DT::now(),
        tbl     => 'Ausweis',
        op      => 'E',
        uid     => (WebMain::auth('user') || {})->{id} || 0,
        ip      => WebMain::auth('ip') || '',
    );
    my @prefld = @upd;
    # Процесс сохранения зависит от того, какие у нас права - только премодерация или можно сразу сохранять
    if (rchk('ausweis_pree')) {
        # preedit - основная таблица
        $preid = sqlAdd(preedit => @preedit, modered => 0)
            || return err => 'db', pref => ['ausweis/info', $aus->{id}];
            
        # Загрузка фото
        if (defined $photo) {
            my $ext = $p->str('photo') =~ /\.([a-zA-Z0-9]{1,5})$/ ? lc($1) : 'jpg';
            my $fname = ImgFile::Save($photo, [preedit => $preid], photo => orig => $ext)
                || return err => 'imgload', pref => ['ausweis/info', $aus->{id}];
        
            push @prefld, photo => $fname;
        }
    }
    else {
        # Одмовляем в БД
        if (@upd) {
            sqlUpd(ausweis => $aus->{id}, @upd)
                || return
                    err  => 'db',
                    ferr => \%err,
                    pref => ['ausweis/edit', $aus->{id}];
        }
        
        # preedit - основная таблица
        $preid = sqlAdd(preedit => @preedit, recid => $aus->{id}, modered => 1)
            || return err => 'db', pref => ['ausweis/info', $aus->{id}];
            
        # Загрузка фото
        if (defined $photo) {
            push @prefld, photo => 'photo';
            _photo_load($aus->{id}, $photo)
                || return
                    err  => 'imgload',
                    pref => ['ausweis/edit', $aus->{id}];
        }
    }
    
    while (@prefld && (my ($p, $v) = splice(@prefld, 0, 2))) {
        sqlAdd(
            preedit_field =>
            eid     => $preid,
            param   => $p,
            value   => $v,
            exists($aus->{$p}) ? (old => $aus->{$p}) : (),
        ) || return err => 'db', pref => ['ausweis/info', $aus->{id}];
    }
    
    return
        ok => 1,
        pref => ['ausweis/info', $aus->{id}];
}

sub regen :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $aus = shift();
    
    redit($aus->{cmdid}) || return err => 'rdenied';
    $aus || return err => 'notfound';
    editable() || return err => 'readonly';

    my @regen = qw/photo print_img print_pdf/;
    my $bar = ImgFile::CachPath(ausweis => $aus->{id}, barcode => $aus->{numid} => orig => 'jpg');
    push(@regen, 'code') unless -s $bar;
    sqlUpd(
        ausweis => $aus->{id},
        regen   => ImgFile::RegenBit(@regen),
    ) || return
            err => 'db',
            pref => ['ausweis/info', $aus->{id}];
    
    return
        ok => 1,
        pref => ['ausweis/info', $aus->{id}];
}

=pod
# Этот функционал мы переработаем иначе.
# Сам код еще пригодится
sub find_repeat {
    my ($self, $id) = @_;

    return unless $self->rights_exists_event($::rAusweisFindRepeat);
    
    my $d = $self->d;
    my $q = $self->req;
    $self->patt(TITLE => $text::titles{"ausweis_find_repeat"});
    $self->view_select->subtemplate("ausweis_find_repeat.tt");
    
    $d->{find} = $q->param_bool('find') || return;
    
    # Общий список аусвайсов
    my %byid;
    my @list = map {
        my ($nick, $fio) = (lc $_->{nick}, lc $_->{fio});
        $_ = _item($self, $_);
        $_->{nick_lc} = $nick;
        $_->{nick_len} = length $nick;
        $_->{fio_lc} = $fio;
        $_->{fio_len} = length $fio;
        $byid{$_->{id}} = $_;
        $_;
    }
    $self->model('Ausweis')->search(
        { blocked => 0 }, 
        { prefetch => 'command', order_by => [qw/command.name nick/] }
    );
    
    # Повторы в никах (Список списков - разбито по группам совпадений)
    $d->{list_nick} = [];
    foreach my $aus1 (@list) {
        $aus1->{nick_len} || return;
        foreach my $aus2 (@list) {
            next if $aus1->{id} == $aus2->{id};
            # Оба ника уже в группах
            next if $aus1->{nick_group} && $aus2->{nick_group};
            # Вхождение ник2 в ник1
            next if index($aus1->{nick_lc}, $aus2->{nick_lc}) < 0;
            # Проверка, чтобы длина ник2 (более короткий) отличалась не более, чем на 20%
            next if (($aus1->{nick_len}-$aus2->{nick_len}) / $aus1->{nick_len}) > 0.2;
            
            if ($aus1->{nick_group}) {
                push @{ $aus1->{nick_group} }, $aus2;
                $aus2->{nick_group} = $aus1->{nick_group};
            }
            elsif ($aus2->{nick_group}) {
                push @{ $aus2->{nick_group} }, $aus1;
                $aus1->{nick_group} = $aus2->{nick_group};
            }
            else {
                my $group = [ $aus1, $aus2 ];
                push @{ $d->{list_nick} }, $group;
                $aus1->{nick_group} = $group;
                $aus2->{nick_group} = $group;
            }
            
        }
    }
    
    # Повторы в фио (Список списков - разбито по группам совпадений)
    $d->{list_fio} = [];
    foreach my $aus1 (@list) {
        $aus1->{fio_len} || next;
        foreach my $aus2 (@list) {
            next if $aus1->{id} == $aus2->{id};
            # Оба фиоа уже в группах
            next if $aus1->{fio_group} && $aus2->{fio_group};
            # Вхождение фио2 в фио1
            next if index($aus1->{fio_lc}, $aus2->{fio_lc}) < 0;
            # Проверка, чтобы длина фио2 (более короткий) отличалась не более, чем на 30%
            next if (($aus1->{fio_len}-$aus2->{fio_len}) / $aus1->{fio_len}) > 0.3;
            
            if ($aus1->{fio_group}) {
                push @{ $aus1->{fio_group} }, $aus2;
                $aus2->{fio_group} = $aus1->{fio_group};
            }
            elsif ($aus2->{fio_group}) {
                push @{ $aus2->{fio_group} }, $aus1;
                $aus1->{fio_group} = $aus2->{fio_group};
            }
            else {
                my $group = [ $aus1, $aus2 ];
                push @{ $d->{list_fio} }, $group;
                $aus1->{fio_group} = $group;
                $aus2->{fio_group} = $group;
            }
            
        }
    }
    
    # Похожие НИК-ФИО (временно отключено)
    $d->{list_comb} = [];
#    foreach my $aus1 (@list) {
#        my $text = "$aus1->{nick_lc} $aus1->{fio_lc}";
#        foreach my $aus ($self->model('Ausweis')->search_nick_fio_full($text, 0, $aus1->{id}, limit => 5, nolog => 1)) {
#            my $aus2 = $byid{$aus->{id}} || next;
#            next if $aus1->{id} == $aus2->{id};
#            # Оба фиоа уже в группах
#            next if $aus1->{comb_group} && $aus2->{comb_group};
#            
#            #$self->debug("[$text] - [$aus2->{nick_lc} $aus2->{fio_lc}] = $aus->{prec}");
#            next if $aus->{prec} < 5;
#            $aus1->{prec} ||= $aus->{prec};
#            
#            if ($aus1->{comb_group}) {
#                push @{ $aus1->{comb_group} }, $aus2;
#                $aus2->{comb_group} = $aus1->{comb_group};
#            }
#            elsif ($aus2->{comb_group}) {
#                push @{ $aus2->{comb_group} }, $aus1;
#                $aus1->{comb_group} = $aus2->{comb_group};
#            }
#            else {
#                my $group = [ $aus1, $aus2 ];
#                push @{ $d->{list_comb} }, $group;
#                $aus1->{comb_group} = $group;
#                $aus2->{comb_group} = $group;
#            }
#            
#        }
#    }
    
}
=cut


1;

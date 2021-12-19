package CMain::Event;

use Clib::strict8;

##################################################

sub by_id {
    sqlGet(event => shift());
}

sub rinfo {
    return 1 if rchk('event_info_all');
    
    my $ev = shift() || return;
    
    return 1
        if ($ev->{status} eq 'O') && rchk('event_info_open');
    
    if (rchk('event_info_last')) {
        my $cnt = sqlCount(event => sqlGE(date => $ev->{date}), sqlNotEq(id => $ev->{id}));
        debug('next event count: %d', $cnt);
        return 1 if defined($cnt) && !$cnt;
    }
    
    return;
}

sub redit {
    return 1 if rchk('event_edit_all');
    
    my $ev = shift() || return;
    
    return 1
        if ($ev->{status} eq 'O') && rchk('event_edit_open');
    
    if (rchk('event_edit_last')) {
        my $cnt = sqlCount(event => sqlGt(id => $ev->{id}));
        return 1 if defined($cnt) && !$cnt;
    }
    
    return;
}

sub _root :
        Simple
{
    my @list;
    if (rchk('event_info_all')) {
        @list = sqlAll(event => 'date');
    }
    elsif (rchk('event_info_last')) {
        @list = sqlSrch(event => sqlOrder('-date', '-id'), sqlLimit(1));
        if (@list && rchk('event_info_open')) {
            @list = (
                sqlSrch(
                    event => 
                    status => 'O',
                    sqlNotEq(id => $list[0]->{id}),
                    sqlOrder('date', 'id')
                ),
                @list
            );
        }
    }
    elsif (rchk('event_info_open')) {
        @list = sqlSrch(event => status => 'O', sqlOrder('date'));
    }
    else {
        return 'rdenied';
    }
    
    return
        'event_list',
        list => \@list,
}

sub info :
        ParamCodeUInt(\&by_id)
{
    my $ev = shift();
    
    rinfo($ev) || return 'rdenied';
    $ev || return 'notfound';
    
    return
        'event_info',
        ev => $ev,
}

sub command :
        ParamCodeUInt(\&by_id)
{
    my $ev = shift();
    
    rinfo($ev) || return 'rdenied';
    $ev || return 'notfound';
    
    my %count_ausweis =
        map { ($_->[0] => $_->[1]) }
        sqlFunc(
            event_ausweis => '`cmdid`, COUNT(*)',
            evid => $ev->{id},
            sqlGroup('cmdid')
        );
    
    my %count_necombat =
        map { ($_->[0] => $_->[1]) }
        sqlFunc(
            event_necombat => '`cmdid`, COUNT(*)',
            evid => $ev->{id},
            sqlGroup('cmdid')
        );
    
    my @money =
        sqlSrch(event_money => evid => $ev->{id});
    my %money = map { ($_->{cmdid} => $_) } @money;
    
    my @cmd = @money ?
        sqlSrch(command => id => [keys %money], sqlOrder('name')) :
        ();
    
    foreach my $cmd (@cmd) {
        $cmd->{count_ausweis} = $count_ausweis{ $cmd->{id} } || 0;
        $cmd->{count_necombat} = $count_necombat{ $cmd->{id} } || 0;
        $cmd->{money} = $money{ $cmd->{id} };
    }
    
    #$self->req->param_bool('xls') &&
    #    return $self->excel("event_command", "event_$ev->{id}_command.xls",
    #                event   => $ev,
    #                list    => \@cmd,
    #            );
    
    return
        'event_command',
        ev => $ev,
        command_list => \@cmd;
}

sub ausweis :
        ParamCodeUInt(\&by_id)
{
    my $ev = shift();
    
    rinfo($ev) || return 'rdenied';
    $ev || return 'notfound';
    
    my $where = '`event`.`evid`=?';
    my @param = ($ev->{id});
    
    my $p = wparam();
    if ($p->exists('cmdid')) {
        $where .= ' AND `event`.`cmdid`=?';
        push @param, $p->uint('cmdid');
    }
    
    my @aus =
        sqlQueryList(
            'SELECT `ausweis`.*, `event`.*, `command`.* ' .
                'FROM `event_ausweis` as `event` ' .
                'LEFT JOIN `ausweis` ON `ausweis`.`id`=`event`.`ausid` ' .
                'LEFT JOIN `command` ON `command`.`id`=`event`.`cmdid` ' .
                'WHERE ' . $where . ' ' .
                'ORDER BY `command`.`name`, `ausweis`.`nick`',
            @param
        );
    
    #$self->req->param_bool('xls') &&
    #    return $self->excel("event_ausweis", "event_$ev->{id}_ausweis.xls",
    #                event   => $ev,
    #                list    => \@aus,
    #            );
    
    return
        'event_ausweis',
        ev => $ev,
        $p->exists('cmdid') ?
            (cmdid => $p->uint('cmdid')) : (),
        ausweis_list => \@aus,
}

sub necombat :
        ParamCodeUInt(\&by_id)
{
    my $ev = shift();
    
    rinfo($ev) || return 'rdenied';
    $ev || return 'notfound';
    
    my $where = '`event`.`evid`=?';
    my @param = ($ev->{id});
    
    my $p = wparam();
    if ($p->exists('cmdid')) {
        $where .= ' AND `event`.`cmdid`=?';
        push @param, $p->uint('cmdid');
    }
    
    my @nec =
        sqlQueryList(
            'SELECT `event`.*, `command`.* ' .
                'FROM `event_necombat` as `event` ' .
                'LEFT JOIN `command` ON `command`.`id`=`event`.`cmdid` ' .
                'WHERE ' . $where . ' ' .
                'ORDER BY `command`.`name`, `event`.`name`',
            @param
        );
    
    #$self->req->param_bool('xls') &&
    #    return $self->excel("event_necombat", "event_$ev->{id}_necombat.xls",
    #                event   => $ev,
    #                list    => \@nec,
    #            );
    
    return
        'event_necombat',
        ev => $ev,
        $p->exists('cmdid') ?
            (cmdid => $p->uint('cmdid')) : (),
        necombat_list => \@nec,
}

sub money :
        ParamCodeUInt(\&by_id)
{
    my $ev = shift();
    
    redit($ev) || return 'rdenied';
    $ev || return 'notfound';
    editable() || return 'readonly';
    
    # Привязка команд к событию
    my %money =
        map { ($_->{cmdid} => $_) }
        sqlSrch(event_money => evid => $ev->{id});
    
    # Покомандные списки
    my @cmd =
        map {
            $_->{money} =
                $money{ $_->{id} } ||
                {
                    price1 => $ev->{price1},
                    price2 => $ev->{price2},
                };
            $_;
        }
        sqlAll(command => 'name');
    
    return
        'event_money',
        ev => $ev,
        command_list => \@cmd,
}

sub moneyset :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $ev = shift();
    
    redit($ev) || return err => 'rdenied';
    $ev || return err => 'notfound';
    editable() || return err => 'readonly';
    my $p = wparam();
    
    # Привязка команд к событию
    my %money =
        map { ($_->{cmdid} => $_) }
        sqlSrch(event_money => evid => $ev->{id});
    
    # Команды
    my @cmd = sqlAll('command');
    
    # Парсим входные данные
    foreach my $cmd (@cmd) {
        $p->exists('cmdid') || next;
        
        my %m;
        $m{allowed}     = $p->bool('allowed.'.$cmd->{id})
                            if $p->exists('allowed.'.$cmd->{id});
        $m{summ}        = sprintf('%0.2f', $p->ufloat('summ.'.$cmd->{id}))
                            if $p->exists('summ.'.$cmd->{id});
        $m{price1}      = sprintf('%0.2f', $p->ufloat('price1.'.$cmd->{id}))
                            if $p->exists('price1.'.$cmd->{id});
        $m{price2}      = sprintf('%0.2f', $p->ufloat('price2.'.$cmd->{id}))
                            if $p->exists('price2.'.$cmd->{id});
        $m{comment}     = $p->str('comment.'.$cmd->{id})
                            if $p->exists('comment.'.$cmd->{id});
        
        my $en = $m{allowed} || (exists($m{summ}) && ($m{summ} > 0));
        my $m = $money{ $cmd->{id} };
        
        if ($en && !$m) {
            # надо добавить
            my @new = (
                evid    => $ev->{id},
                cmdid   => $cmd->{id},
                map { exists($m{$_}) ? ($_ => $m{$_}) : () }
                qw/allowed summ price1 price2 comment/
            );
            sqlAdd(event_money => @new)
                || return
                    err  => 'db',
                    pref => '';
        }
        elsif ($en && $m) {
            # надо изменить
            my @upd = (
                map {
                    exists($m{$_}) && ($m{$_} != $m->{$_}) ? 
                        ($_ => $m{$_}) :
                        ()
                }
                qw/allowed summ price1 price2/
            );
            push(@upd, comment => $m{comment}) if $m{comment} ne $m->{comment};
            if (@upd) {
                sqlUpd(event_money => $m->{id}, @upd)
                    || return
                        err  => 'db',
                        pref => '';
            }
        }
        elsif (!$en && $m) {
            # надо удалить
            sqlDel(event_money => $m->{id})
                || return
                    err  => 'db',
                    pref => '';
        }
    }
    
    return 
        ok => 1,
        pref => ['event/command', $ev->{id}];
}



sub edit :
        ParamCodeUInt(\&by_id)
{
    my $ev = shift();
    
    redit($ev) || return 'rdenied';
    $ev || return 'notfound';
    editable() || return 'readonly';
    
    return
        'event_edit',
        ev => $ev,
        form($ev);
}

sub adding :
        Simple
{
    redit() || return 'rdenied';
    editable() || return 'readonly';
    
    return
        'event_add',
        form(qw/date status name price1 price2/);
}

sub add :
        ReturnOperation
{
    redit() || return err => 'rdenied';
    editable() || return err => 'readonly';
    
    # Проверка данных
    my $p = wparam();
    my %err = ();
    my @new = ();
    
    if ($p->exists('name')) {
        my $name = $p->str('name');
        push @new, name => $name;
        
        if ($name eq '') {
            $err{name} = 'empty';
        }
    }
    else {
        $err{name} = 'nospec';
    }
    
    if ($p->exists('date')) {
        my $date = $p->str('date');
        
        if ($date eq '') {
            $err{date} = 'empty';
        }
        elsif ($date =~ /^(\d\d?)[\.\/\-](\d\d?)[\.\/\-](\d\d\d\d)$/) {
            $date = join '-', $3, $2, $1;
        }
        elsif ($date !~ /^\d\d\d\d-\d\d?-\d\d?$/) {
            $err{date} = 'format';
        }
        
        push @new, date => $date;
    }
    else {
        $err{date} = 'nospec';
    }
    
    if ($p->exists('status')) {
        my $status = $p->code('status');
        push @new, status => $status;
        
        if ($status eq '') {
            $err{status} = 'empty';
        }
        elsif ($status !~ /^[OZ]$/) {
            $err{status} = 'format';
        }
    }
    else {
        push @new, status => 'O';
    }
    
    if ($p->exists('price1')) {
        push @new, price1 => $p->ufloat('price1');
    }
    
    if ($p->exists('price2')) {
        push @new, price2 => $p->ufloat('price2');
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => 'event/adding';
    }
    
    # Сохраняем
    my $evid = sqlAdd(event => @new)
        || return
            err  => 'db',
            ferr => \%err,
            pref => 'event/adding';
        
    return
        ok => 1,
        pref => ['event/info', $evid];
}

sub set :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $ev = shift();
    
    redit($ev) || return err => 'rdenied';
    $ev || return err => 'notfound';
    editable() || return err => 'readonly';
    
    # Проверка данных
    my $p = wparam();
    my %err = ();
    my @upd = ();
    
    if ($p->exists('name')) {
        my $name = $p->str('name');
        push(@upd, name => $name) if $name ne $ev->{name};
        
        if ($name eq '') {
            $err{name} = 'empty';
        }
    }
    
    if ($p->exists('date')) {
        my $date = $p->str('date');
        
        if ($date eq '') {
            $err{date} = 'empty';
        }
        elsif ($date =~ /^(\d\d?)[\.\/\-](\d\d?)[\.\/\-](\d\d\d\d)$/) {
            $date = join '-', $3, $2, $1;
        }
        elsif ($date !~ /^\d\d\d\d-\d\d?-\d\d?$/) {
            $err{date} = 'format';
        }
        
        push(@upd, date => $date) if $date ne $ev->{date};
    }
    
    if ($p->exists('status')) {
        my $status = $p->code('status');
        push(@upd, status => $status) if $status ne $ev->{status};
        
        if ($status eq '') {
            $err{status} = 'empty';
        }
        elsif ($status !~ /^[OZ]$/) {
            $err{status} = 'format';
        }
    }
    
    if ($p->exists('price1')) {
        my $price1 = $p->ufloat('price1');
        push(@upd, price1 => $price1) if $price1 != $ev->{price1};
    }
    
    if ($p->exists('price2')) {
        my $price2 = $p->ufloat('price2');
        push(@upd, price2 => $price2) if $price2 != $ev->{price2};
    }

    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => ['event/edit' => $ev->{id}];
    }
    
    # Надо ли, что сохранять
    if (!@upd) {
        return
            err => 'nochange',
            pref => ['event/info' => $ev->{id}];
    }
    
    # Сохраняем
    sqlUpd(event => $ev->{id}, @upd)
        || return
            err  => 'db',
            ferr => \%err,
            pref => ['event/edit' => $ev->{id}];
        
    return
        ok => 1,
        pref => ['event/info' => $ev->{id}];
}

sub del :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $ev = shift();
    
    redit($ev) || return err => 'rdenied';
    $ev || return err => 'notfound';
    editable() || return err => 'readonly';
    
    my $count =
        sqlCount(event_money => evid => $ev->{id}) ||
        sqlCount(event_ausweis => evid => $ev->{id}) ||
        sqlCount(event_necombat => evid => $ev->{id});
    if ($count) {
        return
            err => c(state => 'eventused'),
            pref => '';
    }
    
    sqlDel(event => $ev->{id})
        || return
            err  => 'db',
            pref => '';
    
    return
        ok => 1,
        pref => 'event';
}

1;

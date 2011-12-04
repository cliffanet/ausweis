package C::Event;

use strict;
use warnings;

##################################################
###     Мероприятия
###     Код модуля: 94
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    my $cmdid = shift;
    
    $item->{status_name} = $text::EventStatus{$item->{status}} || $item->{status};
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{EventShow}, $item->{id}, 'info');
        $item->{href_edit}      = $self->href($::disp{EventShow}, $item->{id}, 'edit');
        $item->{href_command}   = $self->href($::disp{EventShow}, $item->{id}, 'command');
        $item->{href_command_xls}=$self->href($::disp{EventShow}, $item->{id}, 'command_xls');
        $item->{href_money}     = $self->href($::disp{EventShow}, $item->{id}, 'money');
        $item->{href_ausweis}   = $self->href($::disp{EventShow}, $item->{id}, 'ausweis');
        $item->{href_ausweis_xls}=$self->href($::disp{EventShow}, $item->{id}, 'ausweis_xls');
        $item->{href_necombat}  = $self->href($::disp{EventShow}, $item->{id}, 'necombat');
        $item->{href_necombat_xls}=$self->href($::disp{EventShow}, $item->{id}, 'necombat_xls');
        
        $item->{href_set}       = $self->href($::disp{EventSet}, $item->{id});
        $item->{href_del}       = $self->href($::disp{EventDel}, $item->{id});
        $item->{href_delete}    = $self->href($::disp{EventDel}, $item->{id});
        
        $item->{href_set_status}= sub { $self->href($::disp{EventSet}."?status=%s", $item->{id}, shift) };
    }
    
    if ($id && $cmdid) {
        $item->{money} = sub { 
            return $item->{_money} if $item->{_money};
            my $m = ($item->{_money} = 
                $self->ToHtml($self->model('EventMoney')->get($item->{id}, $cmdid)));
                # Цена по умолчанию
            if (($m->{summ}==0) && ($m->{price1}==0) && ($m->{price2}==0) && 
                !$m->{comment} && 
                ($item->{price1} > 0) && ($item->{price2} > 0)) {
                $m->{price1} = $item->{price1};
                $m->{price2} = $item->{price2};
            }
            $m;
        };
        $item->{ausweis_list} = sub {
            $item->{_ausweis_list} ||= [
                map { C::Ausweis::_item($self, $_) }
                $self->model('Ausweis')->search(
                    { cmdid => $cmdid, 'event.evid' => $item->{id} },
                    { prefetch => ['event'] }
                )
            ];
        };
        $item->{href_money_set} = $self->href($::disp{EventMoneySet}, $item->{id}, $cmdid);
        
        $item->{href_necombat_commit} = $self->href($::disp{EventNecombatCommit}, $item->{id}, $cmdid);
        $item->{necombat_list} = sub {
            $item->{_necombat_list} ||= [
                map {
                    my $n = $self->ToHtml($_);
                    $n->{href_decommit} = $self->href($::disp{EventNecombatDeCommit}, $n->{id});
                    $n;
                }
                $self->model('EventNecombat')->search(
                    { evid => $item->{id}, cmdid => $cmdid },
                    { order_by => 'dtadd' }
                )
            ];
        };
    }
    
    return $item;
}

sub list {
    my ($self) = @_;
    my $d = $self->d;

    return unless $self->rights_exists_event($::rEvent);
    
    $self->patt(TITLE => $text::titles{event_list});
    $self->view_select->subtemplate("event_list.tt");

    $d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{EventList})."?sort=$sort";
    };
    my $sort = $self->req->param_str('sort');
    
    $self->d->{list} = [
        map {_item($self, $_); }
        $self->model('Event')->search(
            {},
            {
                $self->sort($sort || 'name'),
            },
        )
    ];
}

sub show {
    my ($self, $evid, $type) = @_;
    my $d = $self->d;
    
    $type = 'info' if !$type || ($type !~ /^(edit|info|money|ausweis(_xls)?|necombat(_xls)?|command(_xls)?)$/);

    return unless $self->rights_exists_event($::rEvent);
    if ($type =~ /^(edit|ausweis(_xls)?|necombat(_xls)?|command(_xls)?)$/) {
        return unless $self->rights_check_event($::rEvent, $::rAdvanced);
    }
    if ($type eq 'money') {
        return unless $self->rights_check_event($::rEvent, $::rWrite, $::rAdvanced);
    }
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Event')->search({ id => $evid }));
    $rec || return $self->state(-000105);
    
    if ($rec->{status} ne 'O') {
        return unless $self->rights_check_event($::rEvent, $::rAdvanced);
    }
    
    return $self->state(-000105)
        if ($type eq 'money') && ($rec->{status} ne 'O');
    
    $d->{form} = $rec || {};
    
    # Тип вывода
    if ($type =~ /^([a-z]+)_xls$/) {
        my $p = $1;
        $self->view_select('Excel', "event_$p", "event_${evid}_$p.xls");
    }
    else {
        $self->patt(TITLE => sprintf($text::titles{"event_$type"}, $rec->{name}));
        $self->view_select->subtemplate("event_$type.tt");
    }
    
    # Ссылки
    $d->{href_set} = $self->href($::disp{EventSet}, $evid);
    $d->{href_money_set} = $self->href($::disp{EventMoneyListSet}, $evid);
    
    # Покомандные списки
    $d->{command_all_list} = sub {
        return $d->{"_command_all_list"} ||= [
            map {
                $_ = C::Command::_item($self, $_);
                my $m = $_->{money};
                if (!$m->{id}) {
                    $m->{id} = 0;
                    foreach my $k (keys %$m) { $m->{$k} = '' };
                    $m->{price1} = $rec->{price1};
                    $m->{price2} = $rec->{price2};
                }
                $_;
            }
            $self->model('Command')->search(
                {}, 
                { 
                    prefetch => 'money',
                    join_cond => { money => { 'money.evid' => $evid } },
                    order_by => 'name',
                }
            )
        ];
    };
    
    $d->{command_list} = sub {
        return $d->{"_command_list"} ||= [
            map {
                my $cmd = C::Command::_item($self, $_);
                $cmd->{count_ausweis} = sub {
                    $d->{_aus_count} ||= {
                        map { ($_->{cmdid} => $_->{count}) }
                        $self->model('Ausweis')->search(
                            { 'event.evid' => $evid },
                            { join => 'event', group_by => 'cmdid',
                                columns => ['cmdid'], '+columns' => ['COUNT(*) as `count`'] }
                        )
                    };
                    return $d->{_aus_count}->{$cmd->{id}} || 0;
                };
                $cmd->{count_necombat} = sub {
                    $d->{_ncmb_count} ||= {
                        map { ($_->{cmdid} => $_->{count}) }
                        $self->model('EventNecombat')->search(
                            { evid => $evid },
                            { group_by => 'cmdid',
                                columns => ['cmdid'], '+columns' => ['COUNT(*) as `count`'] }
                        )
                    };
                    return $d->{_ncmb_count}->{$cmd->{id}} || 0;
                };
                $cmd->{href_event_ausweis} = $self->href($::disp{EventShow}, $evid, 'ausweis')."?cmdid=$cmd->{id}";
                $cmd->{href_event_necombat}= $self->href($::disp{EventShow}, $evid, 'necombat')."?cmdid=$cmd->{id}";
                $cmd;
            }
            $self->model('Command')->search(
                { 'money.allowed' => 1 },
                { 
                    prefetch => 'money',
                    join_cond => { money => { 'money.evid' => $evid } },
                    order_by => 'name',
                }
            )
        ];
    };
    
    # Поименные списки
    my $cmdid;
    if ($cmdid = $self->req->param_dig('cmdid')) {
        $rec->{"href_$_"} .= "?cmdid=$cmdid"
            foreach qw/ausweis ausweis_xls necombat necombat_xls/;
    }
}

sub edit {
    my ($self, $id) = @_;
    
    show($self, $id, 'edit');
    
    my $d = $self->d;
    my $rec = $d->{rec} || return;
    $d->{form} = { map { ($_ => $rec->{$_}) } grep { !ref $rec->{$_} } keys %$rec };
    if ($self->req->params()) {
        my $fdata = $self->ParamData;
        $fdata || return;
        $d->{form}->{$_} = $self->ToHtml($fdata->{$_}) foreach keys %$fdata;
    }
}

sub adding {
    my ($self) = @_;

    return unless $self->rights_check_event($::rEvent, $::rAdvanced);
    
    $self->patt(TITLE => $text::titles{"event_add"});
    $self->view_select->subtemplate("event_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{EventAdd});
    
    # Автозаполнение полей, если данные из формы не приходили
    $d->{form} =
        { map { ($_ => '') } qw/date status name price1 price2/ };
    if ($self->req->params()) {
        # Данные из формы - либо после ParamParse, либо напрямую данные
        my $fdata = $self->ParamData(fillall => 1);
        if (keys %$fdata) {
            $d->{form} = { %{ $d->{form} }, %$fdata };
        } else {
            $d->{form}->{$_} = $self->req->param($_) foreach $self->req->params();
        }
    }
}

sub set {
    my ($self, $id) = @_;
    my $is_new = !defined($id);
    
    return unless $self->rights_check_event($::rEvent, $::rAdvanced);
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Event')->search({ id => $id })) if $id;
    if (!$is_new && (!$rec || !$rec->{id})) {
        return $self->state(-000105, '');
    }
    
    # Проверяем данные из формы
    if (!$self->ParamParse(model => 'Event', is_create => $is_new)) {
        $self->state(-000101);
        return $is_new ? adding($self) : edit($self, $id);
    }
    
    my $fdata = $self->ParamData;
    
    # Сохраняем данные
    my $ret = $self->ParamSave( 
        model           => 'Event', 
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
    
    # Статус с редиректом
    return $self->state($is_new ? 940100 : 940200,  $self->href($::disp{EventShow}, $id, 'info') );
}

sub del {
    my ($self, $id) = @_;
    
    return unless $self->rights_check_event($::rEvent, $::rAdvanced);
    my ($rec) = $self->model('Event')->search({ id => $id });
    $rec || return $self->state(-000105);
    
    my $item;
    ($item) = $self->model('EventAusweis')->search({ evid => $id }, { limit => 1 });
    return $self->state(-940301, '') if $item;
    ($item) = $self->model('EventMoney')->search({ evid => $id }, { limit => 1 });
    return $self->state(-940301, '') if $item;
    
    $self->model('Event')->delete({ id => $id })
        || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(940300, $self->href($::disp{EventList}) );
}


sub money_set {
    my ($self, $evid, $cmdid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEvent, $::rWrite, $::rAdvanced);
    
    my ($rec) = $self->model('Event')->search({ id => $evid, status => 'O' });
    $rec || return $self->state(-000105);
    my ($cmd) = $self->model('Command')->search({ id => $cmdid });
    $cmd || return $self->state(-000105);
    
    my %m;
    $m{allowed} = $q->param_bool('allowed')     if defined $q->param('allowed');
    $m{summ}    = $q->param_float('summ')       if defined $q->param('summ');
    $m{price1}  = $q->param_float('price1')     if defined $q->param('price1');
    $m{price2}  = $q->param_float('price2')     if defined $q->param('price2');
    $m{comment} = $q->param_str('comment')      if defined $q->param('comment');
    
    $self->model('EventMoney')->set($evid, $cmdid, \%m)
        || return $self->state(-000104, '');
        
    # статус с редиректом
    $self->state(940400, '');
}

sub money_list_set {
    my ($self, $evid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEvent, $::rWrite, $::rAdvanced);
    
    # Событие
    my ($rec) = $self->model('Event')->search({ id => $evid, status => 'O' });
    $rec || return $self->state(-000105);
    $evid = $rec->{id};
    
    # Команды
    my %cmd = (
        map { ($_->{id} => $_) }
        $self->model('Command')->search({})
    );
    
    # Привязка команд к событию
    my %money = (
        map { ($_->{cmdid} => $_) }
        $self->model('EventMoney')->search({ evid => $evid })
    );
    
    # Парсим входные данные
    foreach my $cmdid ($q->param_dig('cmdid')) {
        $cmd{$cmdid} || next;
        
        # Данные с формы
        my %d;
        $d{allowed}     = $q->param_bool('allowed.'.$cmdid);
        $d{summ}        = sprintf('%0.2f', $q->param_float('summ.'.$cmdid));
        $d{price1}      = sprintf('%0.2f', $q->param_float('price1.'.$cmdid));
        $d{price2}      = sprintf('%0.2f', $q->param_float('price2.'.$cmdid));
        $d{comment}     = $q->param_str('comment.'.$cmdid);
        
        # Данные все стандартные или особенные
        my $isnull = !$d{allowed} && ($d{summ}<=0) && !$d{comment} &&
            ($d{price1} == $rec->{price1}) && ($d{price2} == $rec->{price2}) ?
            1 : 0;
            
        # Если уже прописаны особенные данные
        if (my $m = $money{$cmdid}) {
            if ($isnull) { # Но введенные не уникальны
                $self->model('EventMoney')->delete({ id => $m->{id} })
                    || return $self->state(-000104);
            }
            else { # Проверяем, изменилось ли какое-то поле
                foreach my $k (qw/allowed summ price1 price2 comment/) {
                    delete $d{$k} if $d{$k} eq $m->{$k};
                }
                if (%d) { # Меняем, если есть, что менять
                    $self->model('EventMoney')->update(\%d, { id => $m->{id} })
                        || return $self->state(-000104);
                }
            }
        }
        # Создаем новую привязку, если данные уникальны
        elsif (!$isnull) { 
            $self->model('EventMoney')->create({
                evid    => $evid,
                cmdid   => $cmdid,
                %d,
            }) || return $self->state(-000104);
        }
    }
        
    # статус с редиректом
    $self->state(940400, $self->href($::disp{EventShow}, $evid, 'info'));
}



sub ausweis_commit {
    my ($self, $evid, $ausid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEventCommit, $::rYes, $::rAdvanced);
    
    my ($rec) = $self->model('Event')->search({ id => $evid, status => 'O' });
    $rec || return $self->state(-000105);
    my ($aus) = $self->model('Ausweis')->search({ id => $ausid, blocked => 0 });
    $aus || return $self->state(-000105);
    
    my ($c) = $self->model('EventAusweis')->search({ evid => $evid, ausid => $ausid });
    $c && return $self->state(-940501, '');
    
    my $m = $self->model('EventMoney')->get($rec->{id}, $aus->{cmdid});
    
    my %c = ( evid => $evid, ausid => $ausid );
    
    $c{payonkpp} = $q->param_bool('payonkpp');
    # Сумма взноса
    if ($c{payonkpp}) {
        $c{price} = $q->param_float('price') if $q->param_float('price') > 0;
    }
    elsif (defined $q->param('price')) {
        $c{price} = $q->param_float('price');
    }
    else {
        if (($m->{summ} > 0) || ($m->{price1} > 0) || $m->{comment}) {
            $c{price} = $m->{price1};
        }
        elsif ($rec->{price1} > 0) {
            $c{price} = $rec->{price1};
        }
    }
    
    defined($c{price}) || return $self->state(-940502, '');
    
    if (($c{price} > 0) && !$c{payonkpp}) {
        # Проверяем, можем ли мы из сданных заранее оплатить
        my @aus = $self->model('Ausweis')->search(
            { cmdid => $aus->{cmdid}, 'event.evid' => $rec->{id}, 'event.payonkpp' => 0 },
            { prefetch => ['event'] }
        );
        my $summ = 0;
        $summ += $_->{event}->{price} foreach @aus;
        
        return $self->state(-940503, '')
            if ($m->{summ}-$summ) < $c{price};
    }
    
    $self->model('EventAusweis')->create(\%c)
        || return $self->state(-000104, '');
    #if ($c{payonkpp}) {
    #    # Увеличиваем суммарный взнос команды
    #    $self->model('EventMoney')->summ_add($rec->{id}, $aus->{cmdid}, $c{price})
    #        || return $self->state(-000104, '');
    #}
        
    # статус с редиректом
    $self->state(940500, '');
}

sub ausweis_decommit {
    my ($self, $evid, $ausid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEventCommit, $::rAdvanced);
    
    my ($c) = $self->model('EventAusweis')->search({ evid => $evid, ausid => $ausid });
    $c || return $self->state(-000105);
    
    $self->model('EventAusweis')->delete({ id => $c->{id} })
        || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(940600, '');
}


sub necombat_commit {
    my ($self, $evid, $cmdid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEventCommit, $::rYes, $::rAdvanced);
    
    my ($rec) = $self->model('Event')->search({ id => $evid, status => 'O' });
    $rec || return $self->state(-000105);
    my ($cmd) = $self->model('Command')->search({ id => $cmdid });
    $cmd || return $self->state(-000105);
    
    my $m = $self->model('EventMoney')->get($rec->{id}, $cmd->{id});
    
    my %c = ( evid => $rec->{id}, cmdid => $cmd->{id} );
    
    $c{name} = $q->param_str('name')
        || return $self->state(-000101, '');
    
    $self->model('EventNecombat')->create(\%c)
        || return $self->state(-000104, '');
        
    # статус с редиректом
    $self->state(940700, '');
}

sub necombat_decommit {
    my ($self, $ncmbid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEventCommit, $::rAdvanced);
    
    my ($c) = $self->model('EventNecombat')->search({ id => $ncmbid });
    $c || return $self->state(-000105);
    
    $self->model('EventNecombat')->delete({ id => $c->{id} })
        || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(940800, '');
}

1;

package C::Event;

use strict;
use warnings;

use Encode '_utf8_on', 'encode';

##################################################
###     Мероприятия
###     Код модуля: 94
#############################################

=pod
sub _item {
    my $self = shift;
    my $item = $self->d->{excel} ? shift : $self->ToHtml(shift, 1);
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
            $item->{_money} = $self->model('EventMoney')->get($item->{id}, $cmdid);
            $item->{_money} = $self->ToHtml($item->{_money}) if !$self->d->{excel};
            my $m = $item->{_money};
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
                    my $n = $self->d->{excel} ? $_ : $self->ToHtml($_);
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
=cut


sub list :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('event_read') || return;
    $self->template("event_list");
    
    my @list = $self->model('Event')->search(
            {},
            {
                order_by => 'date',
            },
        );
    
    return
        list => \@list,
}

sub info :
    ParamObj('event', 0)
    ReturnPatt
{
    my ($self, $ev) = @_;

    $self->view_rcheck('event_read') || return;
    $ev || return $self->notfound;
    $self->template("event_info");
    
    return
        ev => $ev,
}

sub command :
    ParamObj('event', 0)
    ReturnPatt
{
    my ($self, $ev) = @_;

    $self->view_rcheck('event_advanced') || return;
    $ev || return $self->notfound;
    $self->template("event_command");
    
    my %count_ausweis =
        map { ($_->{cmdid} => $_->{count}) }
        $self->model('EventAusweis')->search(
            { evid => $ev->{id} },
            { group_by => 'cmdid',
                columns => ['cmdid'], '+columns' => ['COUNT(*) as `count`'] }
        );
    
    my %count_necombat =
        map { ($_->{cmdid} => $_->{count}) }
        $self->model('EventNecombat')->search(
            { evid => $ev->{id} },
            { group_by => 'cmdid',
                columns => ['cmdid'], '+columns' => ['COUNT(*) as `count`'] }
        );
    
    my @cmd =
        map {
            my $cmd = $_;
            $cmd->{count_ausweis} = $count_ausweis{$cmd->{id}} || 0;
            $cmd->{count_necombat} = $count_necombat{$cmd->{id}} || 0;
            $cmd;
        }
        $self->model('Command')->search(
            { 'money.allowed' => 1 },
            { 
                prefetch => 'money',
                join_cond => { money => { 'money.evid' => $ev->{id} } },
                order_by => 'name',
            }
        );
    
    $self->req->param_bool('xls') &&
        return $self->excel("event_command", "event_$ev->{id}_command.xls",
                    event   => $ev,
                    list    => \@cmd,
                );
    
    return
        ev => $ev,
        command_list => \@cmd,
}

sub ausweis :
    ParamObj('event', 0)
    ReturnPatt
{
    my ($self, $ev) = @_;

    $self->view_rcheck('event_advanced') || return;
    $ev || return $self->notfound;
    $self->template("event_ausweis");
    
    my $cmdid = $self->req->param_dig('cmdid');
    
    my @aus =
        map { 
            my $aus = delete $_->{ausweis};
            $aus->{command} = delete $_->{command};
            $aus->{event} = $_;
            $aus->{event}->{dtadd_format} = Func::dt_datetime($aus->{event}->{dtadd});
            $aus;
        }
        $self->model('EventAusweis')->search(
            { 'evid' => $ev->{id}, $cmdid ? (cmdid=>$cmdid) : () },
            { 
                prefetch => [qw/ausweis command/],
                order_by => [qw/command.name nick/],
            }
        );
    
    $self->req->param_bool('xls') &&
        return $self->excel("event_ausweis", "event_$ev->{id}_ausweis.xls",
                    event   => $ev,
                    list    => \@aus,
                );
    
    return
        ev => $ev,
        $cmdid ? (cmdid => $cmdid) : (),
        ausweis_list => \@aus,
}

sub necombat :
    ParamObj('event', 0)
    ReturnPatt
{
    my ($self, $ev) = @_;

    $self->view_rcheck('event_advanced') || return;
    $ev || return $self->notfound;
    $self->template("event_necombat");
    
    my $cmdid = $self->req->param_dig('cmdid');
    
    my @nec =
        map { 
            my $ncmb = $_;
            $ncmb->{dtadd_format} = Func::dt_datetime($ncmb->{dtadd});
            $ncmb;
        }
        $self->model('EventNecombat')->search(
            { evid => $ev->{id}, $cmdid ? (cmdid=>$cmdid) : () },
            { 
                prefetch => [qw/command/],
                order_by => [qw/command.name name/],
            }
        );
    
    $self->req->param_bool('xls') &&
        return $self->excel("event_necombat", "event_$ev->{id}_necombat.xls",
                    event   => $ev,
                    list    => \@nec,
                );
    
    return
        ev => $ev,
        $cmdid ? (cmdid => $cmdid) : (),
        necombat_list => \@nec,
}

sub money :
    ParamObj('event', 0)
    ReturnPatt
{
    my ($self, $ev) = @_;

    $self->view_rcheck('event_edit') || return;
    $ev || return $self->notfound;
    if ($ev->{status} ne 'O') {
        $self->template('rdenied');
        return;
    }
    $self->d->{read_only} && return $self->cantedit();
    $self->template("event_money");
    
    # Покомандные списки
    my @cmd =
        map {
            my $m = $_->{money};
            if (!$m->{id}) {
                $m->{id} = 0;
                foreach my $k (keys %$m) { $m->{$k} = '' };
                $m->{price1} = $ev->{price1};
                $m->{price2} = $ev->{price2};
            }
            $_;
        }
        $self->model('Command')->search(
            {}, 
            { 
                prefetch => 'money',
                join_cond => { money => { 'money.evid' => $ev->{id} } },
                order_by => 'name',
            }
        );
    
    return
        ev => $ev,
        command_list => \@cmd,
}

sub money_set :
    ParamObj('event', 0)
    ReturnOperation
{
    my ($self, $ev) = @_;
    
    $self->rcheck('event_edit') || return $self->rdenied;
    $ev || return $self->nfound();
    if ($ev->{status} ne 'O') {
        return $self->rdenied;
    }
    $self->d->{read_only} && return $self->cantedit();
    
    my $q = $self->req;
    
    # Команды
    my %cmd = (
        map { ($_->{id} => $_) }
        $self->model('Command')->search({})
    );
    
    # Привязка команд к событию
    my %money = (
        map { ($_->{cmdid} => $_) }
        $self->model('EventMoney')->search({ evid => $ev->{id} })
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
        _utf8_on($d{comment});
        
        # Данные все стандартные или особенные
        my $isnull = !$d{allowed} && ($d{summ}<=0) && !$d{comment} &&
            ($d{price1} == $ev->{price1}) && ($d{price2} == $ev->{price2}) ?
            1 : 0;
            
        # Если уже прописаны особенные данные
        if (my $m = $money{$cmdid}) {
            if ($isnull) { # Но введенные не уникальны
                $self->model('EventMoney')->delete({ id => $m->{id} })
                    || return (error => 000104, href => '');
            }
            else { # Проверяем, изменилось ли какое-то поле
                foreach my $k (qw/allowed summ price1 price2 comment/) {
                    delete $d{$k} if $d{$k} eq $m->{$k};
                }
                if (%d) { # Меняем, если есть, что менять
                    $self->model('EventMoney')->update(\%d, { id => $m->{id} })
                        || return (error => 000104, href => '');
                }
            }
        }
        # Создаем новую привязку, если данные уникальны
        elsif (!$isnull) { 
            $self->model('EventMoney')->create({
                evid    => $ev->{id},
                cmdid   => $cmdid,
                %d,
            }) || return (error => 000104, href => '');
        }
    }
        
    # статус с редиректом
    return (ok => 940400, pref => ['event/info', $ev->{id}]);
}



sub edit :
    ParamObj('event', 0)
    ReturnPatt
{
    my ($self, $ev) = @_;

    $self->view_rcheck('event_advanced') || return;
    $ev || return $self->notfound;
    $self->view_can_edit() || return;
    $self->template("event_edit");
    
    my %form = %$ev;
    if ($self->req->params() && (my $fdata = $self->ParamData)) {
        if (keys %$fdata) {
            $form{$_} = $fdata->{$_} foreach grep { exists $fdata->{$_} } keys %form;
        } else {
            _utf8_on($form{$_} = $self->req->param($_)) foreach $self->req->params();
        }
    }
    
    return
        ev => $ev,
        form => \%form,
        ferror => $self->FormError(),
}

sub adding :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('event_advanced') || return;
    $self->view_can_edit() || return;
    $self->template("event_add");
    
    # Автозаполнение полей, если данные из формы не приходили
    my $form =
        { map { ($_ => '') } qw/date status name price1 price2/ };
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

sub add :
    ReturnOperation
{
    my ($self) = @_;
    
    $self->rcheck('event_advanced') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    
    # Проверяем данные из формы
    $self->ParamParse(model => 'Event', is_create => 1, utf8 => 1)
        || return (error => 000101, pref => 'event/adding', upar => $self->ParamData);
    
    # Сохраняем данные
    my $evid;
    $self->ParamSave( 
        model   => 'Event', 
        insert  => \$evid,
    ) || return (error => 000104, pref => 'event/adding', upar => $self->ParamData);
    
    return (ok => 940100, pref => ['event/info', $evid]);
}

sub set :
    ParamObj('event', 0)
    ReturnOperation
{
    my ($self, $ev) = @_;
    
    $self->rcheck('event_advanced') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $ev || return $self->nfound();
    
    # Проверяем данные из формы
    $self->ParamParse(model => 'Event', utf8 => 1)
        || return (error => 000101, pref => ['event/edit', $ev->{id}], upar => $self->ParamData);
    
    # Сохраняем данные
    $self->ParamSave( 
        model       => 'Event', 
        update      => { id => $ev->{id} }, 
        preselect   => $ev
    ) || return (error => 000104, pref => ['event/edit', $ev->{id}], upar => $self->ParamData);
    
    # Статус с редиректом
    return (ok => 940200, pref => ['event/info', $ev->{id}]);
}

sub del :
    ParamObj('event', 0)
    ReturnOperation
{
    my ($self, $ev) = @_;
    
    $self->rcheck('event_advanced') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $ev || return $self->nfound();
    
    my $item;
    ($item) = $self->model('EventAusweis')->search({ evid => $ev->{id} }, { limit => 1 });
    return (error => 940301, href => '') if $item;
    ($item) = $self->model('EventMoney')->search({ evid => $ev->{id} }, { limit => 1 });
    return (error => 940301, href => '') if $item;
    
    $self->model('Event')->delete({ id => $ev->{id} })
        || return (error => 000104, href => '');
    
    # статус с редиректом
    return (ok => 940300, pref => 'event/list');
}


1;

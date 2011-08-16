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
            if (($m->{summ}==0) && ($m->{price}==0) && !$m->{comment} && ($item->{price} > 0)) {
                # Цена по умолчанию
                $m->{price} = $item->{price};
            }
            $m;
        };
        $item->{ausweis_list} = sub {
            $item->{_ausweis_list} ||= [
                $self->model('Ausweis')->search(
                    { cmdid => $cmdid, 'event.evid' => $item->{id} },
                    { prefetch => ['event'] }
                )
            ];
        };
        $item->{href_money_set} = $self->href($::disp{EventMoneySet}, $item->{id}, $cmdid);
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
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);

    return unless $self->rights_exists_event($::rEvent);
    if ($type eq 'edit') {
        return unless $self->rights_check_event($::rEvent, $::rWrite);
    }
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Event')->search({ id => $evid }));
    $rec || return $self->state(-000105);
    $d->{form} = $rec || {};
    
    $self->patt(TITLE => sprintf($text::titles{"event_$type"}, $rec->{name}));
    $self->view_select->subtemplate("event_$type.tt");
    
    $d->{href_set} = $self->href($::disp{EventSet}, $evid);
    
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

    return unless $self->rights_check_event($::rEvent, $::rWrite);
    
    $self->patt(TITLE => $text::titles{"event_add"});
    $self->view_select->subtemplate("event_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{EventAdd});
    
    # Автозаполнение полей, если данные из формы не приходили
    $d->{form} =
        { map { ($_ => '') } qw/date status name price/ };
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
    
    return unless $self->rights_check_event($::rEvent, $::rWrite);
    
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
    
    return unless $self->rights_check_event($::rEvent, $::rWrite);
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
    
    return unless $self->rights_check_event($::rEvent, $::rWrite);
    
    my ($rec) = $self->model('Event')->search({ id => $evid, status => 'O' });
    $rec || return $self->state(-000105);
    my ($cmd) = $self->model('Command')->search({ id => $cmdid });
    $cmd || return $self->state(-000105);
    
    my %m;
    $m{summ}    = $q->param_float('summ')       if defined $q->param('summ');
    $m{price}   = $q->param_float('price')      if defined $q->param('price');
    $m{comment} = $q->param_str('comment')      if defined $q->param('comment');
    
    $self->model('EventMoney')->set($evid, $cmdid, \%m)
        || return $self->state(-000104, '');
        
    # статус с редиректом
    $self->state(940400, '');
}


sub ausweis_commit {
    my ($self, $evid, $ausid) = @_;
    my $d = $self->d;
    my $q = $self->req;
    
    return unless $self->rights_check_event($::rEvent, $::rWrite);
    
    my ($rec) = $self->model('Event')->search({ id => $evid, status => 'O' });
    $rec || return $self->state(-000105);
    my ($aus) = $self->model('Ausweis')->search({ id => $ausid, blocked => 0 });
    $aus || return $self->state(-000105);
    
    my ($c) = $self->model('EventAusweis')->search({ evid => $evid, ausid => $ausid });
    $c && return $self->state(-940501, '');
    
    my %c = ( evid => $evid, ausid => $ausid );
    
    $c{payonkpp} = $q->param_bool('payonkpp');
    # Сумма взноса
    if ($c{payonkpp}) {
        $c{price} = $q->param_float('price') if $q->param_float('price') > 0;
    }
    else {
        my $m = $self->model('EventMoney')->get($rec->{id}, $aus->{cmdid});
        if (($m->{summ} > 0) || ($m->{price} > 0) || $m->{comment}) {
            $c{price} = $m->{price};
        }
        elsif ($rec->{price} > 0) {
            $c{price} = $rec->{price};
        }
        my @aus = $self->model('Ausweis')->search(
            { cmdid => $aus->{cmdid}, 'event.evid' => $rec->{id} },
            { prefetch => ['event'] }
        );
        my $summ = 0;
        $summ += $_->{event}->{price} foreach @aus;
        return $self->state(-940503, '')
            if ($m->{summ}-$summ) < $c{price};
    }
    defined($c{price}) || return $self->state(-940502, '');
    
    $self->model('EventAusweis')->create(\%c)
        || return $self->state(-000104, '');
    if ($c{payonkpp}) {
        # Увеличиваем суммарный взнос команды
        $self->model('EventMoney')->summ_add($rec->{id}, $aus->{cmdid}, $c{price})
            || return $self->state(-000104, '');
    }
        
    # статус с редиректом
    $self->state(940500, '');
}


1;

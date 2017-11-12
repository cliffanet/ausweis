package C::Ausweis;

use strict;
use warnings;

use Encode '_utf8_on', 'encode';

#use Image::Magick;
use Clib::Mould;

##################################################
###     Основной список
###     Код модуля: 99
#############################################

sub _item {
    my $self = shift;
    
    my $command = delete $_[0]->{command};
    my $blok    = delete $_[0]->{blok};
    
    my $item = $self->d->{excel} ? shift : $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    $item->{command} = C::Command::_item($self, $command)
        if $command;
    $item->{command} ||= sub { C::Command::_hash($self)->{$item->{cmdid}} }
        if $item->{cmdid};
    $item->{blok}    = C::Blok::_item($self, $blok)
        if $blok;
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{AusweisShow}, $item->{id}, 'info');
        $item->{href_edit}      = $self->href($::disp{AusweisShow}, $item->{id}, 'edit');
        
        $item->{href_file}      = sub { $self->href($::disp{AusweisFile}, $item->{id}, shift) };
        $item->{href_regen}     = $self->href($::disp{AusweisRegen}, $item->{id});
        
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('ausweis', $item->{id})."/$file";
        };
        
        Func::regen_stat($self, $item);
    }
    
    if ($item->{print}) {
        $item->{print}->{id} ||= 0;
    }
    
    return $item;
}

sub list :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('ausweis_list') || return;
    $self->template("ausweis_list", 'CONTENT_result');
    
    my $srch = {};
    my $s = $self->req->param_str('srch');
    _utf8_on($s);
    if (my $text = $s) {
        $text =~ s/([%_])/\\$1/g;
        $text =~ s/\*/%/g;
        $text =~ s/\?/_/g;
        $text = "%$text" if $text !~ /^%/;
        $text .= "%" if $text !~ /%$/;
        #$text .= "%" if $text !~ /^(.*[^\\])?%$/;
        
        my $or = ($srch->{-or} = {});
        $or->{$_} = { LIKE => $text }
            foreach qw/nick fio comment krov allerg neperenos polis medik/;
    }
    
    my $numidnick = $self->req->param_str('numidnick');
    _utf8_on($numidnick);
    if (my $num = $numidnick) {
        if ($num =~ /^\d{10}$/) {
            $srch->{numid} = $num;
        }
        else {
            $num =~ s/([%_])/\\$1/g;
            $num =~ s/\*/%/g;
            $num =~ s/\?/_/g;
            $srch->{nick} =  { LIKE => $num };
        }
    }
    
    my $blkid = $self->req->param_dig('blkid');
    my $blok;
    if ($blkid) {
        $srch->{blkid} = $blkid > 0 ? $blkid : 0;
        if ($blkid > 0) {
            $blok = $self->model('Blok')->byId($blkid);
        }
    }
    
    my $cmdid = $self->req->param_dig('cmdid');
    my $cmd;
    if ($cmdid) {
        $srch->{cmdid} = $cmdid > 0 ? $cmdid : 0;
        if ($cmdid > 0) {
            $cmd = $self->model('Command')->byId($cmdid);
        }
    }
    
    my ($count, $countall);
    my @list = $self->model('Ausweis')->search(
            $srch,
            {
                prefetch => [qw/command blok/],
                order_by => 'nick',
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
    
    if ($numidnick && (@list == 1)) {
        $self->redirect($self->pref('ausweis/info', $list[0]->{id}));
    }
    
    return
        srch    => $s,
        numidnick => $numidnick,
        blkid   => $blkid,
        blok    => $blok,
        cmdid   => $cmdid,
        cmd     => $cmd,
        list    => \@list,
        count   => $count,
        countall=> $countall,
}

sub info :
    ParamObj('aus', 0)
    ReturnPatt
{
    my ($self, $aus) = @_;

    $self->view_rcheck('ausweis_info') || return;
    $aus || return $self->notfound;
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $aus->{cmdid})) {
        $self->view_rcheck('ausweis_info_all') || return;
    }
    $self->template("ausweis_info");
    
    my %fmap = (
        photo => 'photo.site.jpg',
        front => 'print.front.jpg',
        rear  => 'print.rear.jpg',
        pdf   => 'print.pdf',
    );
    my $cdir = Func::CachDir('ausweis', $aus->{id});
    my %file = map {
            ("file_$_" => $fmap{$_},
            "file_${_}_size" => -s $cdir.'/'.$fmap{$_})
        }
        keys %fmap;
    
    my $blok;
    $blok = $self->model('Blok')->byId($aus->{blkid}) if $aus->{blkid};
    
    my $cmd;
    $cmd = $self->model('Command')->byId($aus->{cmdid}) if $aus->{cmdid};
    
    return
        aus => $aus,
        %file,
        blok => $blok,
        cmd => $cmd,
}


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
    
    # Премодерация изменений
    $d->{preedit_field} = sub {
        my ($param) = @_;
        $d->{_preedit_field} ||= {
            map { ($_->{field}->{param} => $_->{field}) }
            $self->model('Preedit')->search(
                { tbl => 'Ausweis', op => 'E', recid => $id, modered => 0 },
                { prefetch => 'field', order_by => 'field.id' }
            )
        };
        return {
            exists      => exists($d->{_preedit_field}->{$param}),
            value       => sub { $d->{_preedit_field}->{$param}->{value} },
            href_file   => sub { $self->href($::disp{PreeditFile}, 
                $d->{_preedit_field}->{$param}->{eid}, $param) },
        };
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
    
    $d->{event_commited} = sub {
        $d->{_event_commited} ||= [
            map {
                $_->{ausweis} = C::Ausweis::_item($self, $_->{ausweis});
                $_->{event} = C::Event::_item($self, $_->{event});
                $_->{command} = C::Command::_item($self, $_->{command});
                $_;
            }
            $self->model('EventAusweis')->search({
                ausid   => $rec->{id}
            }, {
                prefetch => [qw/event command/],
                order_by => 'event.date'
            })
        ];
    };
}

sub edit {
    my ($self, $id) = @_;
    
    show($self, $id, 'edit');
    
    $self->can_edit() || return;
    
    my $d = $self->d;    
    my $rec = $d->{rec} || return;
    $d->{form} = { map { ($_ => $rec->{$_}) } grep { !ref $rec->{$_} } keys %$rec };
    if ($self->req->params()) {
        my $fdata = $self->ParamData;
        $fdata || return;
        $d->{form}->{$_} = $self->ToHtml($fdata->{$_}) foreach keys %$fdata;
    }
}

sub file {
    my ($self, $id, $file) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    my $d = $self->d;
    
    my ($rec) = (($d->{rec}) = 
        #map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id }, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105, '');
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $rec->{cmdid})) {
        return unless $self->rights_check_event($::rAusweisInfo, $::rAll);
    }
    
    $file =~ s/[^a-zA-Z\d\.\-]+//g;
    
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('ausweis', $rec->{id})."/$file";
    
    if (my $t = $::AusweisFile{$file}) {
        $d->{type} = $t->[0]||'';
        my $m = Clib::Mould->new();
        $d->{filename} = $m->Parse(data => $t->[1]||'', pattlist => $rec, dot2hash => 1);
    }
}

sub adding {
    my ($self) = @_;

    return unless 
        $self->rights_exists($::rAusweisEdit) ||
        $self->rights_exists_event($::rAusweisPreEdit);
    
    my $cmdid = $self->req->param_dig('cmdid');
    $cmdid ||= $self->user->{cmdid}
        if !$self->rights_check($::rAusweisEdit, $::rAll);
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmdid)) {
        return unless 
            $self->rights_check($::rAusweisEdit, $::rAll) ||
            $self->rights_check_event($::rAusweisPreEdit, $::rAll);
    }
    
    $self->can_edit() || return;
    
    $self->patt(TITLE => $text::titles{"ausweis_add"});
    $self->view_select->subtemplate("ausweis_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{AusweisAdd});
    
    # Автозаполнение полей, если данные из формы не приходили
    $d->{form} =
        { map { ($_ => '') } qw/nick cmdid fio krov allerg neperenos polis medik comment/ };
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
    my ($self, $id, $preedit) = @_;
    my $is_new = !defined($id);
    
    my $dirUpload = Func::SetTmpDir($self)
        || return !$self->state(-900101, '');
    
    $preedit = 1 if !$preedit && !$self->rights_exists($::rAusweisEdit);
    if ($preedit) {
        return unless $self->rights_exists_event($::rAusweisPreEdit);
    } else {
        return unless $self->rights_exists_event($::rAusweisEdit);
    }
    
    $self->can_edit() || return;
    
    my $d = $self->d;
    my $q = $self->req;
    my %sub;
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Ausweis')->search({ id => $id })) if $id;
    if ($is_new) {
        $d->{cmdid} = $q->param_dig('cmdid');
        $d->{cmdid} ||= $self->user->{cmdid}
            if !$self->rights_check($::rAusweisEdit, $::rAll);
        $q->param('cmdid', $d->{cmdid});
        
        $d->{is_blocked} = $q->param_bool('blocked');
        $sub{photo} = { type => '!s', skip => 0 };
    }
    else {
        if (!$rec || !$rec->{id}) {
            return $self->state(-000105, '');
        }
        $d->{cmdid} = $rec->{cmdid};
        
        $d->{is_blocked} = defined $q->param('blocked') ?
            $q->param_bool('blocked') : $rec->{blocked};
    }
    if (!$d->{cmdid} || !$self->user->{cmdid} || ($self->user->{cmdid} != $d->{cmdid})) {
        $preedit = 1 if !$preedit && !$self->rights_check($::rAusweisEdit, $::rAll);
        if ($preedit) {
            return unless $self->rights_check_event($::rAusweisPreEdit, $::rAll);
        } else {
            return unless $self->rights_check_event($::rAusweisEdit, $::rAll);
        }
    }
    
    
    # Проверяем данные из формы
    if (!$self->ParamParse(model => 'Ausweis', subcheck => \%sub, is_create => $is_new)) {
        $self->state(-000101);
        return $is_new ? adding($self) : edit($self, $id);
    }
    
    my $fdata = $self->ParamData;
    delete $fdata->{photo}; # Добавлено в проверку только для проверки обязательности ввода
    
    if ($d->{command} && ($is_new || ($d->{command}->{blkid} != $rec->{blkid}))) {
        $fdata->{blkid} = $d->{command}->{blkid};
    }
    if (!$is_new && !$rec->{numid}) {
        $fdata->{numid} = $self->model('Ausweis')->gen_numid;
    }
    
    my %files;
    if ($preedit) {
        if (my $file = $self->req->param("photo")) {
            %files = (files => { photo => $file });
        }
    } else {
        # Сохраняем данные
        my $ret = $self->ParamSave(
            model           => 'Ausweis', 
            $is_new ?
                ( insert => \$id ) :
                ( 
                    update => { id => $id }, 
                    preselect => $rec
                ),
        );
        
    
        # Загрузка фото
        if (my $file = $self->req->param("photo")) {
            Func::MakeCachDir('ausweis', $id)
                || return $self->state(-900102, '');
            my $photo = Func::ImgCopy($self, "$dirUpload/$file", Func::CachDir('ausweis', $id), 'photo')
                || return $self->state(-900102, '');
            my $regen = $rec ? int($rec->{regen}) : 0;
            $self->model('Ausweis')->update(
                { 
                    regen   => $regen | (1<<($::regen{photo}-1)),
                    photo   => $photo,
                },
                { id => $id }
            ) || return $self->state(-000104, '');
            unlink("$dirUpload/$file");
            
            $self->d->{form_saves} ||= 1;
        }
        
        if (!$ret) {
            $self->state(-000104);
            return $is_new ? adding($self) : edit($self, $id);
        }
        elsif (!$self->d->{form_saves}) {
            return $self->state(-000106, $self->href($::disp{AusweisShow}, $id, 'info'));
        }
    }
    
    my $ret = $self->model('Preedit')->add(
        tbl     => 'Ausweis',
        op      => $is_new ? 'C' : 'E',
        recid   => $id,
        modered => $preedit ? 0 : 1,
        fields  => $fdata,
        old     => $rec,
        %files
    ) || return $self->state(-000104, '');
    return $self->state(-000106, $self->href($::disp{AusweisShow}, $id, 'info'))
        if $ret == 0;
    
    # Статус с редиректом
    if ($preedit && $is_new && $fdata->{cmdid}) {
        return $self->state(990100,  $self->href($::disp{CommandShow}, $fdata->{cmdid}, 'info') );
    }
    return $self->state($is_new ? 990100 : 990200,  $self->href($::disp{AusweisShow}, $id, 'info') );
}


sub regen {
    my ($self, $id) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    
    my ($rec) = (($self->d->{rec}) = 
        #map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id })); #4, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105, '');

    my $r_all = 0;
    my @l = qw/photo print_img print_pdf/;
    push(@l, 'code') unless -s Func::CachDir('ausweis', $rec->{id})."/barcode.$rec->{numid}.orig.jpg";
    $r_all |= 1 << ($::regen{$_}-1) foreach grep { $::regen{$_} } @l;
    $self->model('Ausweis')->update(
        { regen => int($rec->{regen})|int($r_all) },
        { id => $rec->{id} }
    ) || return $self->state(-000104, '');
    
    return $self->state(990400, '');
}

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


1;

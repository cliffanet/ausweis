package C::Command;

use strict;
use warnings;

##################################################
###     Список команд
###     Код модуля: 98
#############################################

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

sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rCommandList);
    
    $self->patt(TITLE => $text::titles{command_list});
    $self->view_select->subtemplate("command_list.tt");
    
    my $d = $self->d;
    my $cmd = $d->{cmd};
    
    my $q = $self->req;
    my $f = {
        cmdid   => $q->param_dig('cmdid'),
        blkid   => $q->param_dig('blkid'),
        name    => $q->param_str('name'),
    };
    $f->{name} ||= '*';
    
    my $srch = {};
    $srch->{id} = $f->{cmdid} if $f->{cmdid};
    if ($f->{blkid}) {
        $srch->{blkid} = $f->{blkid} > 0 ? $f->{blkid} : 0;
    }
    if ($f->{name}) {
        my $name = $f->{name};
        $name =~ s/([%_])/\\$1/g;
        $name =~ s/\*/%/g;
        $name =~ s/\?/_/g;
        #$name = "%$name" if $name !~ /^%/;
        #$name .= "%" if $name !~ /^(.*[^\\])?%$/;
        $srch->{name} = { LIKE => $name };
    }
    
    my $srch_url = 
        join('&',
            (map { $_.'='.Clib::Mould->ToUrl($f->{$_}) }
            grep { $f->{$_} } keys %$f));
    $srch_url ||= '';
    
    $d->{srch} = $self->ToHtml($f);
    
    
    $d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{CommandList})."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{CommandList})."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $d->{list} = [
        map {
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Command')->search(
            $srch,
            {
                prefetch => 'blok',
                $self->sort($sort || 'name'),
            },
            $self->pager($page, 100),
        )
    ] if $srch_url;
    $d->{list} ||= 0;
}

sub show {
    my ($self, $cmdid, $type) = @_;
    my $d = $self->d;
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);

    return unless $self->rights_exists_event($::rCommandInfo);
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmdid)) {
        return unless $self->rights_check_event($::rCommandInfo, $::rAll);
    }
    if ($type eq 'edit') {
        return unless $self->rights_exists_event($::rCommandEdit);
        if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmdid)) {
            return unless $self->rights_check_event($::rCommandEdit, $::rAll);
        }
        $self->can_edit() || return;
    }
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Command')->search({ id => $cmdid }, { prefetch => 'blok' }));
    $rec || return $self->state(-000105);
    $d->{form} = $rec || {};
    
    $self->patt(TITLE => sprintf($text::titles{"command_$type"}, $rec->{name}));
    $self->view_select->subtemplate("command_$type.tt");
    
    $d->{href_set} = $self->href($::disp{CommandSet}, $cmdid);
    $d->{href_logo}= $self->href($::disp{CommandLogo}, $cmdid);
    
    $d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{CommandShow}, $rec->{id}, $type)."?sort=$sort";
    };
    my $sort = $self->req->param_str('sort');
    
    if ($type eq 'info') {
        ($d->{print_open}) = 
            map { C::Print::_item($self, $_) } 
                $self->model('Print')->search(
                    { status => 'A' },
                    { order_by => '-id', limit => 1 }
                );
        $d->{print_open} ||= 0;
    }
    
    $d->{ausweis_list} =  sub {
        $d->{_ausweis_list} ||= [
        map {
                my $item = C::Ausweis::_item($self, $_);
                $item;
        }
        $self->model('Ausweis')->search(
            { cmdid => $rec->{id} },
            {
                $d->{print_open} ? (
                    prefetch        => [qw/print/],
                    join_cond => {
                        print => { prnid => $d->{print_open}->{id} },
                    },
                ) : (),
                $self->sort($sort || 'nick'),
            },
        )
        ];
    };
    
    $d->{ausweis_preedit_list} = sub {
        $d->{_ausweis_preedit_list} ||= [
            map { 
                my $p = $self->ToHtml($_);
                $p->{allow_cancel} = 
                    $self->rights_check($::rPreeditCancel, $::rAll) ? 1 : (
                        $self->rights_check($::rPreeditCancel, $::rMy) ?
                            ($p->{uid} == $self->user->{id} ? 1 : 0) : 0
                    );
                $p->{href_show} = $self->href($::disp{CommandHistory}.'#pre%d', $rec->{id}, $p->{id});
                $p->{href_cancel} = $self->href($::disp{PreeditCancel}, $p->{id});
                $p;
            }
            $self->model('Preedit')->search({
                tbl     => 'Ausweis',
                modered => 0,
                'field_cmdid.value' => $rec->{id},
            }, {
                prefetch => ['field_cmdid', 'field_nick'],
                order_by => 'field_nick.value',
            })
        ];
    };
    
    $d->{allow_event} = $self->rights_exists($::rEvent);
    $d->{allow_event_write} = $self->rights_check($::rEvent, $::rWrite, $::rAdvanced);
    $d->{allow_event_commit} = $self->rights_check($::rEventCommit, $::rYes, $::rAdvanced);
    $d->{event_list} = sub {
        $d->{_event_list} ||= [
            map { C::Event::_item($self, $_, $cmdid); }
            $self->model('Event')->search({
                status  => 'O',
            }, {
                order_by => [qw/date id/],
            })
        ];
    };
    
    $d->{cmd_account_list} = sub {
        return $d->{_cmd_account_list} ||= [
            $self->model('UserList')->search({
                cmdid   => $rec->{id},
            }, {
                prefetch => 'group',
                order_by => 'login',
            })
        ];
    };
    
    $d->{ausweis_history_my} = sub {
        return $d->{_ausweis_history_my} = [
            map {
                $_->{ausweis} = C::Ausweis::_item($self, $_->{ausweis});
                $_->{nick} = $_->{ausweis}->{nick} || $_->{field_nick}->{value} || '';
                $_->{href_hide} = $self->href($::disp{PreeditHide}, $_->{id});
                $_;
            }
            $self->model('Preedit')->search({
                uid     => $self->user->{id},
                tbl     => 'Ausweis',
                modered => { '!=' => 0 },
                visibled=> 1,
                -or     => { 'field_cmdid.value' => $rec->{id}, 'ausweis.cmdid' => $rec->{id} },
            }, {
                prefetch => [qw/field_cmdid field_nick ausweis/],
                order_by => 'id',
            })
        ];
    };
}

sub show_my {
    my ($self, $type) = @_;
    
    my $cmdid = $self->user ? $self->user->{cmdid} : 0;
    $cmdid || return $self->rights_denied();
    
    return show($self, $cmdid, $type);
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

    return unless 
        $self->rights_exists($::rCommandInfo) ||
        $self->rights_exists_event($::rAusweisInfo);
    my $d = $self->d;
    
    my ($rec) = (($d->{rec}) = 
        $self->model('Command')->search({ id => $id }));
    $rec || return $self->state(-000105, '');
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $rec->{id})) {
        return unless 
            $self->rights_check($::rCommandInfo, $::rAll) ||
            $self->rights_check_event($::rAusweisInfo, $::rAll);
    }
    
    $file =~ s/[^a-zA-Z\d\.\-]+//g;
    
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('command', $rec->{id})."/$file";
    
    if (my $t = $::CommandFile{$file}) {
        $d->{type} = $t->[0]||'';
        my $m = Clib::Mould->new();
        $d->{filename} = $m->Parse(data => $t->[1]||'', pattlist => $rec, dot2hash => 1);
    }
}

sub adding {
    my ($self) = @_;

    return unless $self->rights_check_event($::rCommandEdit, $::rAll);
    
    $self->can_edit() || return;
    
    $self->patt(TITLE => $text::titles{"command_add"});
    $self->view_select->subtemplate("command_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{CommandAdd});
    
    # Автозаполнение полей, если данные из формы не приходили
    $d->{form} =
        { map { ($_ => '') } qw/name blkid/ };
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
    
    return unless $self->rights_exists_event($::rCommandEdit);
    if (!$id || !$self->user->{cmdid} || ($self->user->{cmdid} != $id)) {
        return unless $self->rights_check_event($::rCommandEdit, $::rAll);
    }
    
    $self->can_edit() || return;
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Command')->search({ id => $id })) if $id;
    if (!$is_new && (!$rec || !$rec->{id})) {
        return $self->state(-000105, '');
    }
    
    # Проверяем данные из формы
    if (!$self->ParamParse(model => 'Command', is_create => $is_new)) {
        $self->state(-000101);
        return $is_new ? adding($self) : edit($self, $id);
    }
    
    my $fdata = $self->ParamData;
    
    # Сохраняем данные
    my $ret = $self->ParamSave( 
        model           => 'Command', 
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
    
    if (!$is_new && defined($fdata->{blkid}) && ($fdata->{blkid} != $rec->{blkid})) {
        $self->model('Ausweis')->update(
            { blkid => $fdata->{blkid} },
            { cmdid => $id }
        ) || return $self->state(-000104, '');
    }
    
    # Загрузка логотипа
    if (my $file = $self->req->param("photo")) {
        Func::MakeCachDir('command', $id)
            || return $self->state(-900102, '');
        my $photo = Func::ImgCopy($self, "$dirUpload/$file", Func::CachDir('command', $id), 'logo')
            || return $self->state(-900102, '');
        $self->model('Command')->update(
            { 
                regen   => (1<<($::regen{logo}-1)),
                photo   => $photo,
            },
            { id => $id }
        ) || return $self->state(-000104, '');
        unlink("$dirUpload/$file");
    }
    
    # Статус с редиректом
    return $self->state($is_new ? 980100 : 980200,  $self->href($::disp{CommandShow}, $id, 'info') );
}


sub logo {
    my ($self, $id) = @_;
    
    my $dirUpload = Func::SetTmpDir($self)
        || return !$self->state(-900101, '');
    
    return unless $self->rights_exists_event($::rCommandLogo);
    if (!$id || !$self->user->{cmdid} || ($self->user->{cmdid} != $id)) {
        return unless $self->rights_check_event($::rCommandLogo, $::rAll);
    }
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Command')->search({ id => $id }));
    if (!$rec || !$rec->{id}) {
        return $self->state(-000105, '');
    }
    
    # Загрузка логотипа
    my $file = $self->req->param("photo") 
        || return $self->state(-000101, '');
        
        Func::MakeCachDir('command', $id)
            || return $self->state(-900102, '');
        my $photo = Func::ImgCopy($self, "$dirUpload/$file", Func::CachDir('command', $id), 'logo')
            || return $self->state(-900102, '');
        $self->model('Command')->update(
            { 
                regen   => (1<<($::regen{logo}-1)),
                photo   => $photo,
            },
            { id => $id }
        ) || return $self->state(-000104, '');
        unlink("$dirUpload/$file");
    
    # Статус с редиректом
    return $self->state(980200, $self->href($::disp{CommandShow}, $id, 'info'));
}


sub del {
    my ($self, $id) = @_;
    
    return unless $self->rights_check_event($::rCommandEdit, $::rAll);
    
    $self->can_edit() || return;
    
    my ($rec) = $self->model('Command')->search({ id => $id });
    $rec || return $self->state(-000105);
    
    my ($item) = $self->model('Ausweis')->search({ cmdid => $id }, { limit => 1 });
    return $self->state(-980301) if $item;
    
    $self->model('Command')->delete({ id => $id })
        || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(980300, $self->href($::disp{CommandList}) );
}



sub history {
    my ($self, $cmdid) = @_;
    my $d = $self->d;
    
    return unless $self->rights_exists_event($::rCommandInfo);
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmdid)) {
        return unless $self->rights_check_event($::rCommandInfo, $::rAll);
    }
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Command')->search({ id => $cmdid }, { prefetch => 'blok' }));
    $rec || return $self->state(-000105);
    
    $self->patt(TITLE => sprintf($text::titles{"command_history"}, $rec->{name}));
    $self->view_select->subtemplate("command_history.tt");
    
    $d->{list} = sub {
        return $d->{_list} if $d->{_list};
        # id затрагиваемых аусвайсов
        my %ausid = (map { ($_->{id}=>1) } $self->model('Ausweis')->search({ cmdid=>$cmdid }));
        # id preedit на создание аусвайса
        my %eid_create = (
            map { ($_->{eid}=>1) } 
            $self->model('PreeditField')->search(
                { param => 'cmdid', value => $cmdid, 'edit.op' => 'C', 'edit.tbl' => 'Ausweis' },
                { join => 'edit' }
            )
        );
        
        my %eid;
        $d->{_list} = [
            map {
                my $p = C::Preedit::_item($self, $_);
                $eid{$p->{id}}=$p;
                $p->{field_list} = [];
                $p->{allow_cancel} = 
                    $self->rights_check($::rPreeditCancel, $::rAll) ? 1 : (
                        $self->rights_check($::rPreeditCancel, $::rMy) ?
                            ($p->{uid} == $self->user->{id} ? 1 : 0) : 0
                    );
                $p->{href_cancel} = $self->href($::disp{PreeditCancel}, $p->{id});
                $p;
            }
            $self->model('Preedit')->search([
                    %eid_create ? { id => [keys %eid_create] } : (),
                    %ausid ? { tbl=>'Ausweis', recid=>[keys %ausid] } : ()
                ], {
                    prefetch    => ['user', 'ausweis'],
                    order_by    => 'id'
                })
        ] if %eid_create || %ausid;
        if (%eid) {
            push( @{ $eid{$_->{eid}}->{field_list} }, $_)
                foreach 
                    map { $_->{enold} = defined $_->{old}; $_ }
                    $self->model('PreeditField')->search(
                        { eid => [keys %eid] }, 
                        { order_by => 'field' }
                    );
        }
        $d->{_list};
    };
}


sub event_list {
    my ($self, $cmdid) = @_;
    my $d = $self->d;
    
    return unless $self->rights_exists_event($::rCommandInfo);
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmdid)) {
        return unless $self->rights_check_event($::rCommandInfo, $::rAll);
    }
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Command')->search({ id => $cmdid }, { prefetch => 'blok' }));
    $rec || return $self->state(-000105);
    
    $self->patt(TITLE => sprintf($text::titles{"command_event_list"}, $rec->{name}));
    $self->view_select->subtemplate("command_event_list.tt");
    
    $d->{list} = sub {
        return $d->{_list} if $d->{_list};
        my %ev;
        $d->{_list} = [
            map {
                my $ev = C::Event::_item($self, $_);
                $ev->{ausweis_list} = [];
                $ev{$ev->{id}} = $ev;;
                $ev;
            }
            $self->model('Event')->search(
                {},
                { $self->sort('date'), },
            )
        ];
        map {
            my $aus = C::Ausweis::_item($self, $_);
            $aus->{command} = C::Command::_item($self, $aus->{command});
            push @{ $ev{ $aus->{event}->{evid} }->{ausweis_list} }, $aus;
        }
        $self->model('Ausweis')->search({
            'event.cmdid' => $rec->{id}
        }, {
            prefetch => [qw/event command/],
            order_by => 'nick'
        });
        $d->{_list};
    };
}


1;

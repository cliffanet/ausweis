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
    
    my $item = $self->ToHtml(shift, 1);
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
        
        $item->{href_file}      = sub { $self->href($::disp{CommandFile}, $item->{id}, shift) };
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('command', $item->{id})."/$file";
        };
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

    return unless $self->rights_exists_event($::rCommandInfo);
    my $d = $self->d;
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $cmdid)) {
        return unless $self->rights_check_event($::rCommandInfo, $::rAll);
    }
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Command')->search({ id => $cmdid }, { prefetch => 'blok' }));
    $rec || return $self->state(-000105);
    
    
    $self->patt(TITLE => sprintf($text::titles{"command_$type"}, $rec->{name}));
    $self->view_select->subtemplate("command_$type.tt");
    
    $d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{CommandShow}, $rec->{id}, $type)."?sort=$sort";
    };
    my $sort = $self->req->param_str('sort');
    
    $d->{ausweis_list} =  sub {
        $d->{_ausweis_list} ||= [
        map {
                my $item = C::Ausweis::_item($self, $_);
                $item;
        }
        $self->model('Ausweis')->search(
            { cmdid => $rec->{id} },
            {
                $self->sort($sort || 'nick'),
            },
        )
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
    return show($self, $id, 'edit');
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
    
    $self->patt(TITLE => $text::titles{"command_add"});
    $self->view_select->subtemplate("command_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{CommandAdd});
    
    $d->{form} =
        { map { ($_ => '') } qw/name blkid/ };
    if ($self->req->params()) {
        # Автозаполнение полей, если данные из формы не приходили
        $d->{form} = {
            %{ $d->{form} },
            %{ $self->ParamData(fillall => 1) },
        };
    }
    #$d->{form}->{comment_nobr} = $self->ToHtml($d->{form}->{comment});
    #$d->{form}->{comment} = $self->ToHtml($d->{form}->{comment}, 1);
}

sub set {
    my ($self, $id) = @_;
    my $is_new = !defined($id);
    
    return unless $self->rights_exists_event($::rCommandEdit);
    if (!$id || !$self->user->{cmdid} || ($self->user->{cmdid} != $id)) {
        return unless $self->rights_check_event($::rCommandEdit, $::rAll);
    }
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Command')->search({ id => $id })) if $id;
    if (!$is_new && (!$rec || !$rec->{id})) {
        $self->state(-000105);
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
            { blkid => $rec->{blkid} }
        ) || return $self->state(-000104, '');
    }
    
    # Статус с редиректом
    return $self->state($is_new ? 980100 : 980200,  $self->href($::disp{CommandShow}, $id, 'info') );
}

sub del {
    my ($self, $id) = @_;
    
    return unless $self->rights_check_event($::rCommandEdit, $::rAll);
    my ($rec) = $self->model('Command')->search({ id => $id });
    $rec || return $self->state(-000105);
    
    my ($item) = $self->model('Ausweis')->search({ cmdid => $id }, { limit => 1 });
    return $self->state(-980301) if $item;
    
    $self->model('Command')->delete({ id => $id })
        || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(980300, $self->href($::disp{CommandList}) );
}




1;

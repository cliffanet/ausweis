package C::Blok;

use strict;
use warnings;

##################################################
###     Список команд
###     Код модуля: 97
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{BlokShow}, $item->{id}, 'info');
        $item->{href_edit}      = $self->href($::disp{BlokShow}, $item->{id}, 'edit');
        $item->{href_del}       = $self->href($::disp{BlokDel}, $item->{id});
        $item->{href_delete}    = $self->href($::disp{BlokDel}, $item->{id});
        
        $item->{href_file}      = sub { $self->href($::disp{BlokFile}, $item->{id}, shift) };
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('blok', $item->{id})."/$file";
        };
        
        $item->{href_cmd_adding}= $self->href($::disp{CommandAdding}."?blkid=%d", $id);
    }
    
    return $item;
}

sub _list {
    my $self = shift;
    return $self->d->{blk}->{_list} ||= [
        map { _item($self, $_); }
        $self->model('Blok')->search({},{order_by=>'name'})
    ];
}

sub _hash {
    my $self = shift;
    return $self->d->{blk}->{_hash} ||= {
        map { ($_->{id} => $_) }
        @{ _list($self) }
    };
}

sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rBlokList);
    
    $self->patt(TITLE => $text::titles{blok_list});
    $self->view_select->subtemplate("blok_list.tt");
    
    my $blk = $self->d->{blk};
    
    my $q = $self->req;
    my $f = {
        blkid   => $q->param_dig('blkid'),
        name    => $q->param_str('name'),
    };
    $f->{name} ||= '*';
    
    my $srch = {};
    $srch->{id} = $f->{blkid} if $f->{blkid};
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
    
    $self->d->{srch} = $self->ToHtml($f);
    
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{BlokList})."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $self->d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{BlokList})."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $self->d->{list} = [
        map {
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Blok')->search(
            $srch,
            {
                $self->sort($sort || 'name'),
            },
            $self->pager($page, 100),
        )
    ] if $srch_url;
    $self->d->{list} ||= 0;
}

sub show {
    my ($self, $blkid, $type) = @_;
    my $d = $self->d;
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);

    return unless $self->rights_exists_event($::rBlokInfo);
    
    if (!$self->user->{blkid} || ($self->user->{blkid} != $blkid)) {
        return unless $self->rights_check_event($::rBlokInfo, $::rAll);
    }
    ##### Права на едактирование
    if ($type eq 'edit') {
        return unless $self->rights_exists_event($::rBlokEdit);
        if (!$self->user->{blkid} || ($self->user->{blkid} != $blkid)) {
            return unless $self->rights_check_event($::rBlokEdit, $::rAll);
        }
    }
    
    $d->{rec} ||= ($self->model('Blok')->search({ id => $blkid }))[0];
    $d->{rec} || return $self->state(-000105);
    my ($rec) = ($d->{rec} =  _item($self, $d->{rec}));
    $d->{form} = $rec;
    
    $self->patt(TITLE => sprintf($text::titles{"blok_$type"}, $rec->{name}));
    $self->view_select->subtemplate("blok_$type.tt");
    
    $d->{href_set} = $self->href($::disp{BlokSet}, $blkid);
    
    ##### Список команд
    $d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{BlokShow}, $rec->{id}, $type)."?sort=$sort";
    };
    my $sort = $self->req->param_str('sort');
    
    $d->{command_list} =  sub {
        $d->{_command_list} ||= [
        map {
                my $item = C::Command::_item($self, $_);
                $item;
        }
        $self->model('Command')->search(
            { blkid => $rec->{id} },
            {
                $self->sort($sort || 'name'),
            },
        )
        ];
    };
}

sub show_my {
    my ($self, $type) = @_;
    
    my $blkid = $self->user ? $self->user->{blkid} : 0;
    $blkid || return $self->rights_denied();
    
    return show($self, $blkid, $type);
}

sub edit {
    my ($self, $id) = @_;
    
    show($self, $id, 'edit');
    
    my $d = $self->d;    
    my $rec = $d->{rec};
    $d->{form} = { map { ($_ => $rec->{$_}) } grep { !ref $rec->{$_} } keys %$rec };
    if ($self->req->params()) {
        my $fdata = $self->ParamData;
        $d->{form}->{$_} = $self->TiHtml($fdata->{$_}) foreach keys %$fdata;
    }
}

sub file {
    my ($self, $id, $file) = @_;

    return unless 
        $self->rights_exists($::rBlokInfo) ||
        $self->rights_exists_event($::rCommandInfo);
    my $d = $self->d;
    
    my ($rec) = (($d->{rec}) = 
        $self->model('Blok')->search({ id => $id }));
    $rec || return $self->state(-000105, '');
    
    if (!$self->user->{blkid} || ($self->user->{blkid} != $rec->{id})) {
        return unless 
            $self->rights_check($::rBlokInfo, $::rAll) ||
            $self->rights_check_event($::rCommandInfo, $::rAll);
    }
    
    $file =~ s/[^a-zA-Z\d\.\-]+//g;
    
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('blok', $rec->{id})."/$file";
    
    if (my $t = $::BlokFile{$file}) {
        $d->{type} = $t->[0]||'';
        my $m = Clib::Mould->new();
        $d->{filename} = $m->Parse(data => $t->[1]||'', pattlist => $rec, dot2hash => 1);
    }
}

sub adding {
    my ($self) = @_;

    return unless $self->rights_check_event($::rBlokEdit, $::rAll);
    
    $self->patt(TITLE => $text::titles{"blok_add"});
    $self->view_select->subtemplate("blok_add.tt");
    
    my $d = $self->d;
    $d->{href_add} = $self->href($::disp{BlokAdd});
    
    $d->{form} =
        { map { ($_ => '') } qw/name/ };
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
    
    return unless $self->rights_exists_event($::rBlokEdit);
    if (!$id || !$self->user->{blkid} || ($self->user->{blkid} != $id)) {
        return unless $self->rights_check_event($::rBlokEdit, $::rAll);
    }
    
    # Кэшируем заранее данные
    my ($rec) = (($self->d->{rec}) = $self->model('Blok')->search({ id => $id })) if $id;
    if (!$is_new && (!$rec || !$rec->{id})) {
        return $self->state(-000105, '');
    }
    
    # Проверяем данные из формы
    if (!$self->ParamParse(model => 'Blok', is_create => $is_new)) {
        $self->state(-000101);
        return $is_new ? adding($self) : edit($self, $id);
    }
    
    # Сохраняем данные
    my $ret = $self->ParamSave( 
        model           => 'Blok', 
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
    return $self->state($is_new ? 970100 : 970200,  $self->href($::disp{BlokShow}, $id, 'info') );
}

sub del {
    my ($self, $id) = @_;
    
    return unless $self->rights_check_event($::rBlokEdit, $::rAll);
    my ($rec) = $self->model('Blok')->search({ id => $id });
    $rec || return $self->state(-000105);
    
    $self->model('Blok')->delete({ id => $id })
        || return $self->state(-000104, '');
        
    # Убираем блок у команд
    $self->model('Command')->update(
        { blkid => 0 },
        { blkid => $id },
    ) || return $self->state(-000104, '');
    
    # Убираем блок у аусвайсов
    $self->model('Ausweis')->update(
        { blkid => 0 },
        { blkid => $id },
    ) || return $self->state(-000104, '');
    
    # статус с редиректом
    $self->state(970300, $self->href($::disp{BlokList}) );
}



1;

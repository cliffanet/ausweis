package C::Command;

use strict;
use warnings;

##################################################
###     Список команд
###     Код модуля: 98
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{CommandShow}, $item->{id}, 'info');
        $item->{href_srch}      = $self->href($::disp{AusweisList}."?cmdid=%d", $item->{id});
        #$item->{href_del}       = $self->href($::disp{CommandDel}, $item->{id});
        #$item->{href_delete}    = $self->href($::disp{CommandDel}, $item->{id});
        
        $item->{href_photo}     = $item->{photo} ? "$::urlPhoto/command/$item->{photo}" : '';
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
    
    my $cmd = $self->d->{cmd};
    
    my $q = $self->req;
    my $f = {
        cmdid   => $q->param_dig('cmdid'),
        blkid   => $q->param_dig('blkid'),
        name    => $q->param_str('name'),
    };
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
    
    use Data::Dumper;
    $self->debug(Dumper($srch));
    
    my $srch_url = 
        join('&',
            (map { $_.'='.Clib::Mould->ToUrl($f->{$_}) }
            grep { $f->{$_} } keys %$f));
    $srch_url ||= '';
    
    $self->d->{srch} = $self->ToHtml($f);
    
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{CommandList})."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $self->d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{CommandList})."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $self->d->{list} = [
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
    $self->d->{list} ||= 0;
}

sub show {
    my ($self, $cmdid, $type) = @_;

    return unless $self->rights_exists_event($::rCommandInfo);
    
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
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{CommandShow}, $rec->{id}, $type)."?sort=$sort";
    };
    my $sort = $self->req->param_str('sort');
    
    $self->d->{ausweis} =  sub {
        $self->d->{_ausweis} ||= [
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


1;

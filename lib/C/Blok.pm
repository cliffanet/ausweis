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
        $item->{href_del}       = $self->href($::disp{BlokDel}, $item->{id});
        $item->{href_delete}    = $self->href($::disp{BlokDel}, $item->{id});
        
        $item->{href_file}      = sub { $self->href($::disp{BlokFile}, $item->{id}, shift) };
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('blok', $item->{id})."/$file";
        };
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

    return unless $self->rights_exists_event($::rBlokInfo);
    
    if (!$self->user->{blkid} || ($self->user->{blkid} != $blkid)) {
        return unless $self->rights_check_event($::rBlokInfo, $::rAll);
    }
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Blok')->search({ id => $blkid }));
    $rec || return $self->state(-000105);
    
    $self->patt(TITLE => sprintf($text::titles{"blok_$type"}, $rec->{name}));
    $self->view_select->subtemplate("blok_$type.tt");
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{BlokShow}, $rec->{id}, $type)."?sort=$sort";
    };
    my $sort = $self->req->param_str('sort');
    
    $self->d->{command_list} =  sub {
        $self->d->{_command_list} ||= [
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



1;

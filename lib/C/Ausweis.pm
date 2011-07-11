package C::Ausweis;

use strict;
use warnings;

#use Image::Magick;
use Clib::Mould;

##################################################
###     Основной список
###     Код модуля: 99
#############################################

sub _item {
    my $self = shift;
    my $command = delete $_[0]->{command};
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    $item->{command} = C::Command::_item($self, $command)
        if $command;
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{AusweisShow}, $item->{id}, 'info');
        #$item->{href_del}       = $self->href($::disp{AusweisDel}, $item->{id});
        #$item->{href_delete}    = $self->href($::disp{AusweisDel}, $item->{id});
        
        #$item->{href_photo}     = $item->{photo} ? "$::urlPhoto/ausweis/$item->{photo}" : '';
        #$item->{href_photo}     = $item->{photo} ? $self->href($::disp{AusweisShow}, $item->{id}, 'photo') : '';
        
        $item->{href_file}      = sub { $self->href($::disp{AusweisFile}, $item->{id}, shift) };
        $item->{href_regen}     = $self->href($::disp{AusweisRegen}, $item->{id});
        
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('ausweis', $item->{id})."/$file";
        };
    }
    
    $item->{regenb} =
        sub { $item->{_regenb} ||= [0, split(//, reverse sprintf("%b", $item->{regen}))] };
    $item->{regenl} = sub {
        return $item->{_regenl} if $item->{_regenl};
        my $list = ($item->{_regenl} = []);
        my $n = 0;
        foreach my $b (@{ $item->{regenb}->() }) {
            push(@$list, $n) if $b;
            $n++;
        }
        $item->{_regenl};
    };
    $item->{regens} = 
        sub { $item->{_regens} ||= join(', ', map { $text::regen{$_} } @{ $item->{regenl}->() }); };
    
    return $item;
}


sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rAusweisList);
    
    $self->patt(TITLE => $text::titles{ausweis_list});
    $self->view_select->subtemplate("ausweis_list.tt");
    
    my $q = $self->req;
    my $f = {
        cmdid   => $q->param_dig('cmdid'),
        blkid   => $q->param_dig('blkid'),
        text    => $q->param_str('text'),
    };
    my $srch = {};
    $srch->{cmdid} = $f->{cmdid} if $f->{cmdid};
    $srch->{blkid} = $f->{blkid} if $f->{blkid};
    if ($f->{text}) {
        my $text = $f->{text};
        $text =~ s/([%_])/\\$1/g;
        $text =~ s/\*/%/g;
        $text =~ s/\?/_/g;
        #$text = "%$text" if $text !~ /^%/;
        #$text .= "%" if $text !~ /^(.*[^\\])?%$/;
        
        $srch->{-or} = {};
        $srch->{-or}->{$_} = { LIKE => $text }
            foreach qw/nick fio comment krov allerg neperenos polis medik/;
    }
    
    my $srch_url = 
        join('&',
            (map { $_.'='.Clib::Mould->ToUrl($f->{$_}) }
            grep { $f->{$_} } keys %$f));
    $srch_url ||= '';
    
    $self->d->{srch} = $self->ToHtml($f);
    
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{AusweisList})."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $self->d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{AusweisList})."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $self->d->{list} = [
        map {
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Ausweis')->search(
            $srch,
            {
                prefetch => [qw/command blok/],
                $self->sort($sort || 'nick'),
            },
            $self->pager($page, 100),
        )
    ] if $srch_url;
    $self->d->{list} ||= 0;
}


sub show {
    my ($self, $id, $type) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    my $d = $self->d;
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id }, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105);
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $rec->{cmdid})) {
        return unless $self->rights_check_event($::rAusweisInfo, $::rAll);
    }
    
    $self->patt(TITLE => sprintf($text::titles{"ausweis_$type"}, $rec->{nick}));
    $self->view_select->subtemplate("ausweis_$type.tt");
    
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


sub regen {
    my ($self, $id) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    
    my ($rec) = (($self->d->{rec}) = 
        #map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id })); #4, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105, '');

    my $r_all = 0;
    $r_all |= 1 << ($::regen{$_}-1) 
        foreach grep { $::regen{$_} } qw/photo print_img print_pdf/;    
    $self->model('Ausweis')->update(
        { regen => int($rec->{regen})|int($r_all) },
        { id => $rec->{id} }
    ) || return $self->state(-000104, '');
    
    return $self->state(990104, '');
}


1;

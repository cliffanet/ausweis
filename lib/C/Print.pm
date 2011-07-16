package C::Print;

use strict;
use warnings;

##################################################
###     Вывод на печать (партии печати)
###     Код модуля: 96
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    $item->{status_name} = $text::PrintStatus{$item->{status}} || $item->{status};
    
    if ($id) {
        # Ссылки
        $item->{href_info}      = $self->href($::disp{PrintInfo}, $item->{id});
        $item->{href_set}       = $self->href($::disp{PrintSet}, $item->{id});
        
        $item->{href_set_status}= sub { $self->href($::disp{PrintSet}."?status=%s", $item->{id}, shift) };
        
        $item->{href_regen}     = $self->href($::disp{PrintRegen}, $item->{id});
        $item->{href_file}      = sub { $self->href($::disp{PrintFile}, $item->{id}, shift) };
        $item->{file_size} = sub {
            my $file = shift;
            $file || return;
            return $item->{"_file_size_$file"} ||=
                -s Func::CachDir('Print', $item->{id})."/$file";
        };
    
        $item->{href_ausweis_search} = $self->href($::disp{PrintAusweisSearch}, $item->{id});
        $item->{href_ausweis_add} = $self->href($::disp{PrintAusweisAdd}, $item->{id});
        $item->{href_ausweis_del} = $self->href($::disp{PrintAusweisDel}, $item->{id});
        
        Func::regen_stat($self, $item);
    }
    
    return $item;
}

sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rPrint);
    
    $self->patt(TITLE => $text::titles{print_list});
    $self->view_select->subtemplate("print_list.tt");
    
    $self->d->{list} = [
        map {_item($self, $_); }
        $self->model('Print')->search(
            {},
            {
                order_by        => 'id',
            },
        )
    ];
}

sub info {
    my ($self, $id) = @_;
    my $d = $self->d;
    
    return unless $self->rights_exists_event($::rPrint);
    
    $d->{rec} ||= ($self->model('Print')->search({ id => $id }))[0];
    $d->{rec} || return $self->state(-000105);
    my ($rec) = ($d->{rec} =  _item($self, $d->{rec}));
    
    $self->patt(TITLE => sprintf($text::titles{"print_info"}, $rec->{id}));
    $self->view_select->subtemplate("print_info.tt");
    
    $d->{status_name} = \%text::PrintStatus;
    
    $d->{allow_print_ausweis} = $self->rights_check($::rPrintAusweis, $::rAll);
    
    $self->{href_ausweis_search} = $self->href($::disp{PrintAusweisSearch}, $rec->{id});
}

sub file {
    my ($self, $id, $file) = @_;

    return unless $self->rights_exists_event($::rPrint);
    my $d = $self->d;
    
    my ($rec) = (($d->{rec}) = 
        $self->model('Print')->search({ id => $id }));
    $rec || return $self->state(-000105, '');
    
    $file =~ s/[^a-zA-Z\d\.\-]+//g;
    
    $self->view_select('File');
    
    $d->{file} = Func::CachDir('print', $rec->{id})."/$file";
    
    if (my $t = $::PrintFile{$file}) {
        $d->{type} = $t->[0]||'';
        my $m = Clib::Mould->new();
        $d->{filename} = $m->Parse(data => $t->[1]||'', pattlist => $rec, dot2hash => 1);
    }
}

sub add {
    my ($self) = @_;

    return unless $self->rights_check_event($::rPrint, $::rWrite);
    
    $self->model('Print')->create({})
        || return $self->state(-000104, '');
    my $id = $self->model('Print')->insertid;

    # Статус с редиректом
    return $self->state(960100,  $self->href($::disp{PrintInfo}, $id) );
}

sub regen {
    my ($self, $id) = @_;

    return unless $self->rights_check_event($::rPrint, $::rWrite);
    
    my ($rec) = (($self->d->{rec}) = 
        $self->model('Print')->search({ id => $id }));
    $rec || return $self->state(-000105, '');

    my $r_all = 0;
    $r_all |= 1 << ($::regen{print_pdf}-1) ;
    #    foreach grep { $::regen{$_} } qw/photo print_img print_pdf/;    
    $self->model('Print')->update(
        { regen => int($rec->{regen})|int($r_all) },
        { id => $rec->{id} }
    ) || return $self->state(-000104, '');
    
    return $self->state(960400, '');
}


sub set {
    my ($self, $id) = @_;

    return unless $self->rights_check_event($::rPrint, $::rWrite);
    
    my $d = $self->d;
    my $q = $self->req;
    
    my ($rec) = (($d->{rec}) = 
        $self->model('Print')->search({ id => $id }));
    $rec || return $self->state(-000105, '');

    my %rec = ();
    
    if ($q->param('status') && ($q->param('status') =~ /^[ACPZ]$/)) {
        $rec{status} = $q->param_code('status');
    }
    
    foreach my $p (keys %rec) {
        delete($rec{$p}) if $rec{$p} eq $rec->{$p};
    }
    
    %rec || return $self->state(-000106, '');

    $self->model('Print')->update(
        \%rec,
        { id => $rec->{id} }
    ) || return $self->state(-000104, '');
    
    return $self->state(960200, '');
}


sub ausweis_search {
    my ($self, $id) = @_;
    my $d = $self->d;

    return unless $self->rights_check_event($::rPrintAusweis, $::rAll);
    
    $self->patt(TITLE => $text::titles{print_ausweis});
    $self->view_select->subtemplate("print_ausweis.tt");
    
    $d->{rec} ||= ($self->model('Print')->search({ id => $id }))[0];
    $d->{rec} || return $self->state(-000105);
    my ($rec) = ($d->{rec} =  _item($self, $d->{rec}));
    
    $self->{href_ausweis_search} = $self->href($::disp{PrintAusweisSearch}, $rec->{id});
    
    my $q = $self->req;
    my $f = {
        cmdid   => $q->param_dig('cmdid'),
        blkid   => $q->param_dig('blkid'),
        text    => $q->param_str('text'),
    };
    my $srch = { blocked => 0 };
    $srch->{cmdid} = $f->{cmdid} if $f->{cmdid};
    $srch->{blkid} = $f->{blkid} if $f->{blkid};
    if ($f->{text}) {
        my $text = $f->{text};
        $text =~ s/([%_])/\\$1/g;
        $text =~ s/\*/%/g;
        $text =~ s/\?/_/g;
        
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
        return $self->href($::disp{PrintAusweisSearch}, $id)."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $self->d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{PrintAusweisSearch}, $id)."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $d->{list} = [
        map { C::Ausweis::_item($self, $_); }
        $self->model('Ausweis')->search(
            $srch,
            {
                prefetch => [qw/command blok/],
                $self->sort($sort || 'nick'),
            },
            $self->pager($page, 100),
        )
    ] if $srch_url;
    $d->{list} ||= 0;
    
    
}    

sub ausweis_add {
    my ($self, $id) = @_;
    my $d = $self->d;

    return unless $self->rights_check_event($::rPrintAusweis);
    
    $d->{rec} ||= ($self->model('Print')->search({ id => $id }))[0];
    $d->{rec} || return $self->state(-000105);
    
    return $self->state(960500, '');
}

sub ausweis_del {
    my ($self, $id) = @_;
    my $d = $self->d;

    return unless $self->rights_check_event($::rPrintAusweis);
    
    $d->{rec} ||= ($self->model('Print')->search({ id => $id }))[0];
    $d->{rec} || return $self->state(-000105);
    
    return $self->state(960600, '');
}


1;

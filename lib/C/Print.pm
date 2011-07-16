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
    my ($self, $blkid) = @_;
    my $d = $self->d;
    
    return unless $self->rights_exists_event($::rPrint);
    
    $d->{rec} ||= ($self->model('Print')->search({ id => $blkid }))[0];
    $d->{rec} || return $self->state(-000105);
    my ($rec) = ($d->{rec} =  _item($self, $d->{rec}));
    
    $self->patt(TITLE => sprintf($text::titles{"print_info"}, $rec->{id}));
    $self->view_select->subtemplate("print_info.tt");
    
    $d->{status_name} = \%text::PrintStatus;
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



1;

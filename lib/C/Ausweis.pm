package C::Ausweis;

use strict;
use warnings;

use Image::Magick;
use Clib::Mould;

##################################################
###     �������� ������
###     ��� ������: 99
#############################################

sub _item {
    my $self = shift;
    my $command = delete $_[0]->{command};
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    $item->{command} = C::Command::_item($self, $command)
        if $command;
    
    if ($id) {
        # ������
        $item->{href_info}      = $self->href($::disp{AusweisShow}, $item->{id}, 'info');
        #$item->{href_del}       = $self->href($::disp{AusweisDel}, $item->{id});
        #$item->{href_delete}    = $self->href($::disp{AusweisDel}, $item->{id});
        
        $item->{href_photo}     = $item->{photo} ? "$::urlPhoto/ausweis/$item->{photo}" : '';
        
        $item->{href_img_front} = $self->href($::disp{AusweisImage}, $item->{id}, 'front');
        $item->{href_img_rear}  = $self->href($::disp{AusweisImage}, $item->{id}, 'rear');
    }
    
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

sub img {
    my ($self, $id, $type) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    
    $type = 'info' if !$type || ($type !~ /^(front|rear)$/);
    
    my ($rec) = (($self->d->{rec}) = 
        #map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id }, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105, '');
    
    if (!$self->user->{cmdid} || ($self->user->{cmdid} != $rec->{cmdid})) {
        return unless $self->rights_check_event($::rAusweisInfo, $::rAll);
    }
    
    my $width = $::print{width} || 200;
    my $height= $::print{height}|| 400;
    my $img = ($self->d->{img} = Image::Magick->new(size => "${width}x${height}"));
    $img || return $self->state(-000100, '');
    my $bg = $::print{bgcolor} || 'transparent';
    $img->ReadImage("xc:$bg");
    
    $self->view_select('Image');

    my @opt = @{ $::print{$type} || [] };
    use Data::Dumper;
    while (my $p = shift @opt) {
        my $o = shift @opt || next;
        next unless ref($o) eq 'HASH';
        
        my $error;
        $self->debug("opts[$p]: ".Dumper($o));
        if (lc($p) eq 'area') {
            #$o->{stroke} ||= $o->{color} if $o->{color};
            $o->{fill} ||= $bg;
            $error = $img->Draw(primitive=>'rectangle', %$o);
        }
        elsif ((lc($p) eq 'text') && $o->{text}) {
            my $m = Clib::Mould->new();
            $o->{text} = $m->Parse(data => $o->{text}, pattlist => $rec);
            $self->debug("TEXT: $o->{text}");
            
            my ($x_ppem, $y_ppem, $ascender, $descender, $w, $h, $max_advance)
                = $img->QueryFontMetrics(%$o);
            $self->debug("TEXT: $x_ppem, $y_ppem, $ascender, $descender, $w, $h, $max_advance");
        }
        elsif ((lc($p) eq 'photo') && $o->{x} && $o->{y} && $rec->{photo}) {
            my $file = "$::dirPhoto/ausweis/$rec->{photo}";
            {
                my $img1 = Image::Magick->new();
                $error = $img1->Read($file);
                $error && last;
                my ($w, $h) = ($img1->Get('width'), $img->Get('height'));
                my $k = $o->{width} && ($o->{width} < $w) ? $o->{width}/$w : 1;
                $k = $o->{height}/$h if $o->{height} && (($o->{height}/$h) < $k);
                if ($k < 1) {
                    $error = $img1->Resize(width=>$w*$k, height=>$h*$k);
                    $error && last;
                }
                $error = $img->Composite(image => $img1, x=>$o->{x}, y=>$o->{y});
                $error && last;
            }
        }
        
        $self->error("Image::Magick ERROR(%s): %s", $p, $error)
            if $error;
    }
}


1;

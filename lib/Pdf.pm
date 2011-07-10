package Pdf;

use strict;
use warnings;

use PDF::API2;
use Clib::Mould;

##################################################################
######
######  Преподготовка печатной формы - pdf
######

sub Ausweis {
    my ($self, $pdf, $rec) = @_;

    if (ref($rec) ne 'HASH') {
        ($rec) =
            $self->model('Ausweis')->search({ id => $rec }, { prefetch => [qw/command blok/] });
        $rec || return;
    }

    my $page = $pdf->page;
    


    my @opt = @::print_pdf;
    use Data::Dumper;
    my ($ox, $oy) = (0, 0);
    while (my $p = shift @opt) {
        my $o = shift @opt || next;
        next unless ref($o) eq 'HASH';
        $o = { %$o }; # Копия хеша с параметрами, чтобы его можно было править
        
        eval {
        
        #$self->debug("opts[$p]: ".Dumper($o));
        if (my $if = delete $o->{if}) {
            $self->debug("opts[$p]: if=$if");
            my $ret = eval $if;
            $self->error("opts[$p]: if=$if; ERROR: $@") if $@;
            $ret || next;
        }
        
        if (lc($p) eq 'offset') {
            $ox = $o->{x} if defined $o->{x};
            $oy = $o->{y} if defined $o->{y};
            next;
        }
        
        $o->{$_} += $ox
            foreach grep { defined $o->{$_} } qw/x x1 x2/;
        $o->{$_} += $oy
            foreach grep { defined $o->{$_} } qw/y y1 y2/;
        $o->{$_} *= 2.835
            foreach grep { defined $o->{$_} } qw/x x1 x2 y y1 y2/;
        $o->{$_} = 842-$o->{$_}
            foreach grep { defined $o->{$_} } qw/y y1 y2/;
        
        if (lc($p) eq 'area') {
            $self->debug('AREA: %s', join('', Dumper($o)));
            my $gfx = $page->gfx;
            $gfx->strokecolor($o->{color}) if $o->{color};
            $gfx->move($o->{x1}||0, $o->{y1}||0);
            $gfx->line($o->{x2}||0, $o->{y1}||0);
            $gfx->line($o->{x2}||0, $o->{y2}||0);
            $gfx->line($o->{x1}||0, $o->{y2}||0);
            $gfx->line($o->{x1}||0, $o->{y1}||0);
            $gfx->stroke;
        }
        elsif ((lc($p) eq 'text') && $o->{text}) {
            my $m = Clib::Mould->new();
            $o->{text} = $m->Parse(data => $o->{text}, pattlist => $rec, dot2hash => 1);
            $self->debug("TEXT: $o->{text}");
            
            $o->{font} ||= 'arial.ttf';
            my $fnt = $pdf->ttfont("$::font_dir/$o->{font}", -encode=>'cp1251'); 
            my $txt = $page->text;
            $txt->textstart;
            $txt->font($fnt, $o->{size}||10);
            $txt->translate($o->{x}||0, $o->{y}||0);
            $txt->fillcolor($o->{color}) if $o->{color};
            if ($o->{align} eq 'right') {
                $txt->text_right($o->{text});
            } elsif ($o->{align} eq 'center') {
                $txt->text_center($o->{text});
            } else {
                $txt->text($o->{text});
            }
            $txt->textend;
        }
#        elsif ((((lc($p) eq 'photo') && $rec->{photo}) || 
#                ((lc($p) eq 'logo') && $rec->{command}->{photo})) && 
#                    $o->{x} && $o->{y}) {
#            my $file = lc($p) eq 'photo' ? 
#                #"$::dirPhoto/ausweis/$rec->{photo}" :
#                Func::UserDir($rec->{id})."/photo.aus.jpg" :
#                "$::dirPhoto/command/$rec->{command}->{photo}";
#            {
#                my $img1 = Image::Magick->new();
#                $error = $img1->Read($file);
#                $error && last;
#                $error = $img1->AutoOrient();
#                $error && last;
#                my ($w, $h) = ($img1->Get('width'), $img1->Get('height'));
#                my $k = $o->{width} && ($o->{width} < $w) ? $o->{width}/$w : 1;
#                $k = $o->{height}/$h if $o->{height} && (($o->{height}/$h) < $k);
#                if ($k < 1) {
#                    $self->debug("IMG: orig = %dx%d, k=%0.4f, new = %dx%d", $w, $h, $k, $w*$k, $h*$k);
#                    $error = $img1->Resize(width=>int($w*$k), height=>int($h*$k));
#                    $error && last;
#                    $w = int($w*$k);
#                }
#                if ($o->{width} && $o->{align} && ($o->{align} =~ /right/i)) {
#                    $o->{x} += $o->{width}-$w if $o->{width}>$w;
#                } elsif ($o->{width} && $o->{align} && ($o->{align} =~ /center/i)) {
#                    $o->{x} += int ($o->{width}-$w)/2 if $o->{width}>$w;
#                }
#                $error = $img->Composite(image => $img1, x=>$o->{x}, y=>$o->{y});
#                $error && last;
#            }
#        }
#        elsif ((lc($p) eq 'barcode') && $rec->{numid}) {
#            my $file = "$::dirPhoto/barcode/$rec->{numid}.jpg";
#            if (-f $file) { {
#                my $img1 = Image::Magick->new();
#                $error = $img1->Read($file);
#                $error && last;
#                my ($w, $h) = ($img1->Get('width'), $img1->Get('height'));
#                $error = $img1->Crop(x=>0,y=>0, width=>$w, height=>int($h*0.4));
#                $error && last;
#                $error = $img1->Resize(width=>int($o->{width}||$w), height=>int($o->{height}||$h));
#                $error && last;
#                $error = $img->Composite(image => $img1, x=>$o->{x}, y=>$o->{y});
#                $error && last;
#            } }
#        }
        
        };
        
        $self->error("PDF::API2 ERROR: %s", $@)
            if $@;
    }
    



    
    return $page;
}




####################################################

1;

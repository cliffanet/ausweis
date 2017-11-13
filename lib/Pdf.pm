package Pdf;

use strict;
use warnings;

use PDF::API2;
use Clib::Mould;
use Image::Magick;

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
            $ret || return;
        }
        
        if (lc($p) eq 'offset') {
            $ox = $o->{x} if defined $o->{x};
            $oy = $o->{y} if defined $o->{y};
            return;
        }
        
        $o->{$_} += $ox
            foreach grep { defined $o->{$_} } qw/x x1 x2/;
        $o->{$_} += $oy
            foreach grep { defined $o->{$_} } qw/y y1 y2/;
        $o->{$_} *= 2.835
            foreach grep { defined $o->{$_} } qw/x x1 x2 y y1 y2 width height stroke/;
        $o->{$_} = 842-$o->{$_}
            foreach grep { defined $o->{$_} } qw/y y1 y2/;
        
        if (lc($p) eq 'area') {
            $self->debug('AREA: %s', join('', Dumper($o)));
            my $gfx = $page->gfx;
            $gfx->save;
            $gfx->strokecolor($o->{color}||'black');
            $gfx->linewidth($o->{stroke}) if $o->{stroke};
            $gfx->linedash($o->{dash}) if $o->{dash};
            $gfx->move($o->{x1}||0, $o->{y1}||0);
            $gfx->line($o->{x2}||0, $o->{y1}||0);
            $gfx->line($o->{x2}||0, $o->{y2}||0);
            $gfx->line($o->{x1}||0, $o->{y2}||0);
            $gfx->line($o->{x1}||0, $o->{y1}||0);
            $gfx->stroke;
            $gfx->restore;
        }
        elsif ((lc($p) eq 'text') && $o->{text}) {
            my $m = Clib::Mould->new();
            $o->{text} = $m->Parse(data => $o->{text}, pattlist => $rec, dot2hash => 1);
            $self->debug("TEXT: $o->{text}");
            
            $o->{text} || return;
            $o->{font} ||= 'arial.ttf';
            my $fnt = $pdf->ttfont("$::font_dir/$o->{font}");#, -encode=>'cp1251'); 
            my $txt = $page->text;
            $txt->textstart;
            $txt->font($fnt, $o->{size}||10);
            $txt->translate($o->{x}||0, $o->{y}||0);
            $txt->fillcolor($o->{color}||'black');
            if ($o->{align} && ($o->{align} eq 'right')) {
                $txt->text_right($o->{text});
            } elsif ($o->{align} && ($o->{align} eq 'center')) {
                $txt->text_center($o->{text});
            } else {
                $txt->text($o->{text});
            }
            $txt->textend;
        }
        elsif ((((lc($p) eq 'photo') && $rec->{photo}) || 
                ((lc($p) eq 'logo') && $rec->{command}->{photo})) && 
                    $o->{x} && $o->{y}) {
            my $file = lc($p) eq 'photo' ? 
                Func::CachDir('ausweis', $rec->{id})."/photo.aus.jpg" :
                Func::CachDir('command', $rec->{cmdid})."/logo.aus.jpg";
                
            my ($w, $h);
            {
                my $img1 = Image::Magick->new();
                $img1->Read($file);
                #$img1->AutoOrient();
                ($w, $h) = ($img1->Get('width'), $img1->Get('height'));
                my $k = $o->{width} && ($o->{width} < $w) ? $o->{width}/$w : 1;
                $k = $o->{height}/$h if $o->{height} && (($o->{height}/$h) < $k);
                $self->debug("IMG: orig = %dx%d, k=%0.4f, new = %dx%d", $w, $h, $k, $w*$k, $h*$k);
                ($w, $h) = ($w*$k, $h*$k);
                if ($o->{width} && $o->{align} && ($o->{align} =~ /right/i)) {
                    $o->{x} += $o->{width}-$w if $o->{width}>$w;
                } elsif ($o->{width} && $o->{align} && ($o->{align} =~ /center/i)) {
                    $o->{x} += ($o->{width}-$w)/2 if $o->{width}>$w;
                }
            }
            
            my $gfx = $page->gfx;
            my $img = $pdf->image_jpeg($file);
            $gfx->image( $img, $o->{x}, $o->{y}, $w, $h );
        }
        elsif ((lc($p) eq 'barcode') && $rec->{numid}) {
            $self->debug('BarCode: %s', join('', Dumper($o)));
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
            my $gfx = $page->gfx;
            my $fnt = $pdf->ttfont("$::font_dir/arial.ttf");#, -encode=>'cp1251'); 
            $o->{width} ||= 51*2.835;
            my $k = $o->{width}/(51*2.835);
            my $bc =  $pdf->xo_code128(
                    -font   => $fnt,    # the font to use for text
                    #-ean => 1,
                    -type   => 'b',    # the type of barcode
                    -code   => $rec->{numid}, # the code of the barcode
                #    -extn   => '012345',    # the extension of the barcode
                    -umzn   => 10,         # (u)pper (m)ending (z)o(n)e -  высота штриха
                #    -lmzn   => 10,         # (l)ower (m)ending (z)o(n)e -  высота теста, если нужен текст
                    -zone   => $o->{height}/$k,         # height (zone) of bars,
                #    -quzn   => 10,         # (qu)iet (z)o(n)e - горизонтальные поля
                    -ofwt   => 0.001,       # (o)ver(f)low (w)id(t)h
                    #-fnsz   => 5,          # (f)o(n)t(s)i(z)e
                    #-text   => 'alternative text'
                    );
            my $fi = $gfx->formimage($bc, $o->{x}, $o->{y}, $k);
        }
        
        };
        
        $self->error("PDF::API2 ERROR: %s", $@)
            if $@;
    }
    



    
    return $page;
}



##################################################################
######
######  Генерация штрихкода - через PDF - в изображение через Image::Magick
######

sub GenNumId {
    my ($self, $numid, $file) = @_;
    
    $file || return;
    my ($dir, $filename) = ($1, $2) if $file =~ /^(.+)\/([^\\\/]+)$/;
    
    my $pdf_file = "$dir/tmp.$numid.pdf";
    my $pdf = eval { PDF::API2->new(-file => $pdf_file) };
    if (!$pdf) {
        $self->error("Can't create PDF-file: $@");
        return;
    }
    $pdf->mediabox(595,842);
    my $page = $pdf->page;
    
    my $gfx = $page->gfx;
    my $fnt = $pdf->ttfont("$::font_dir/arial.ttf");#, -encode=>'cp1251'); 
    my $bc =  $pdf->xo_code128(
        -font   => $fnt,    # the font to use for text
        #-ean => 1,
        -type   => 'b',    # the type of barcode
        -code   => $numid, # the code of the barcode
    #    -extn   => '012345',    # the extension of the barcode
        -umzn   => 10,         # (u)pper (m)ending (z)o(n)e -  высота штриха
    #    -lmzn   => 10,         # (l)ower (m)ending (z)o(n)e -  высота теста, если нужен текст
        -zone   => 100,         # height (zone) of bars,
    #    -quzn   => 10,         # (qu)iet (z)o(n)e - горизонтальные поля
        -ofwt   => 0.001,       # (o)ver(f)low (w)id(t)h
        #-fnsz   => 5,          # (f)o(n)t(s)i(z)e
        #-text   => 'alternative text'
    );
    my $fi = $gfx->formimage($bc, 0, 0, 1);
    
    $pdf->save;
    $pdf->end( );
    undef $pdf;
    $self->log("Gen NUMID[$numid]-pdf OK");
    
    my $img = Image::Magick->new();
    my $error;
    if ($error = $img->Read($pdf_file)) {
        $self->error("Image::Magick->Read: $error");
        return;
    }
    if ($error = $img->Crop(x=>0,y=>750, width=>152, height=>80)) {
        $self->error("Image::Magick->Crop: $error");
        return;
    }
    if ($error = $img->Write(filename => "$dir/$filename", quality => 100)) {
        $self->error("Image::Magick->Write: $error");
        return;
    }
    undef $img;
    unlink $pdf_file;
    $self->log("Gen NUMID[$numid]-jpg($file) OK");
    return $numid;
}


####################################################

1;

package Func;

use strict;
use warnings;

use Encode 'decode';

####################################################

sub UserDir {
    my $id = shift;
    $id || return;
    $::dirFiles || return;
    
    $id = sprintf("%06d", $id);
    my ($d1, $d2, $d3) = ($1, $2, $3)
        if $id =~ /^(\d+)(\d\d)(\d\d)$/;
        
    return "$::dirFiles/ausweis/$d1/$d2/$d3";
}

sub MakeUserDir {
    my $id = shift;
    $id || return;
    $::dirFiles || return;
    
    $id = sprintf("%06d", $id);
    my ($d1, $d2, $d3) = ($1, $2, $3)
        if $id =~ /^(\d+)(\d\d)(\d\d)$/;
        
    if (!(-d $::dirFiles)) {
        mkdir($::dirFiles) || return;
    }
    if (!(-d "$::dirFiles/ausweis")) {
        mkdir("$::dirFiles/ausweis") || return;
    }
    if (!(-d "$::dirFiles/ausweis/$d1")) {
        mkdir("$::dirFiles/ausweis/$d1") || return;
    }
    if (!(-d "$::dirFiles/ausweis/$d1/$d2")) {
        mkdir("$::dirFiles/ausweis/$d1/$d2") || return;
    }
    if (!(-d "$::dirFiles/ausweis/$d1/$d2/$d3")) {
        mkdir("$::dirFiles/ausweis/$d1/$d2/$d3") || return;
    }
        
    return 1;
}

####################################################

sub SaveImg {
    my ($self, $src_file, $dst_dir, $prefix) = @_;
    
    $src_file || return '0E0';
    
    if (!(-f $src_file)) {
        $self->error("file not found ($src_file)");
        return;
    }
    
    if (!open(FHI, $src_file)) {
        $self->error("Can't read photo file($src_file): $!");
        return;
    }
    
    my $ext = lc $1 if $src_file =~ /\.([a-zA-Z0-9]{1,5})$/;
    $ext ||= 'jpg';
    my $file = "$prefix.orig.$ext";
    
    if (!open(FHO, ">$dst_dir/$file")) {
        $self->error("Can't copy photo (-> $dst_dir/$file): $!");
        close FHI;
        return;
    }
    
    print FHO <FHI>;
    close FHO;
    close FHI;
    
    foreach my $ikey (keys %::imgSize) {
        my $s = $::imgSize{$ikey};
        
        my $img = Image::Magick->new();
        if (!$img) {
            $self->error("Image::Magick->new Error");
            return;
        }
        if (my $error = $img->Read($src_file)) {
            $self->error("Image::Magick->Read($src_file): $error");
            return;
        }
        if (my $error = $img->AutoOrient()) {
            $self->error("Image::Magick->AutoOrient: $error");
            #next;
        }
        my ($width, $height) = ($img->Get('width'), $img->Get('height'));
        if (!$width || !$height) {
            $self->error("Image::Magick: Geometry error");
            next;
        }
        
        if ($s->{width}) {
            my $k=$s->{width}/$width;
            ($width, $height) = ($s->{width}, int $height*$k);
            if (my $error = $img->Resize(width=>$width, height=>$height)) {
                $self->error("Image::Magick->Resize($width, $height): $error");
                next;
            }
        }
        
        if (my $error = $img->Write(
                filename => "$dst_dir/$prefix.$ikey.jpg", 
                compression => 'JPEG', 
                quality => 100)) {
            $self->error("Image::Magick->Write: $error");
            next;
        }
    }
    
    1;
}



##################################################################
######
######  Преподготовка печатной формы - jpg-картинка
######

sub ausweis_img {
    my ($self, $rec, $type) = @_;

    if (ref($rec) ne 'HASH') {
        ($rec) =
            $self->model('Ausweis')->search({ id => $rec }, { prefetch => [qw/command blok/] });
        $rec || return;
    }
    
    my $width = $::print_img{width} || 200;
    my $height= $::print_img{height}|| 400;
    my $img = Image::Magick->new(size => "${width}x${height}");
    $img || return;
    my $bg = $::print_img{bgcolor} || 'transparent';
    $img->ReadImage("xc:$bg");
    if ($::print_img{density}) {
        $img->Set(density=>$::print_img{density});
        $img->Set(units=>"PixelsPerInch");
    }

    my @opt = @{ $::print_img{$type} || [] };
    use Data::Dumper;
    while (my $p = shift @opt) {
        my $o = shift @opt || next;
        next unless ref($o) eq 'HASH';
        
        #$self->debug("opts[$p]: ".Dumper($o));
        if (my $if = delete $o->{if}) {
            $self->debug("opts[$p]: if=$if");
            my $ret = eval $if;
            $self->error("opts[$p]: if=$if; ERROR: $@") if $@;
            $ret || next;
        }
        
        my $error;
        if (lc($p) eq 'area') {
            #$o->{stroke} ||= $o->{color} if $o->{color};
            $o->{fill} ||= $bg;
            $error = $img->Draw(primitive=>'rectangle', %$o);
        }
        elsif ((lc($p) eq 'text') && $o->{text} && $o->{x} && $o->{y}) {
            my $m = Clib::Mould->new();
            $o->{text} = $m->Parse(data => $o->{text}, pattlist => $rec, dot2hash => 1);
            $self->debug("TEXT: $o->{text}");
            $o->{text} = decode('cp1251', $o->{text});
            
            $error = $img->Annotate(antialias=>'true', %$o);
            
        }
        elsif ((((lc($p) eq 'photo') && $rec->{photo}) || 
                ((lc($p) eq 'logo') && $rec->{command}->{photo})) && 
                    $o->{x} && $o->{y}) {
            my $file = lc($p) eq 'photo' ? 
                #"$::dirPhoto/ausweis/$rec->{photo}" :
                Func::UserDir($rec->{id})."/photo.aus.jpg" :
                "$::dirPhoto/command/$rec->{command}->{photo}";
            {
                my $img1 = Image::Magick->new();
                $error = $img1->Read($file);
                $error && last;
                $error = $img1->AutoOrient();
                $error && last;
                my ($w, $h) = ($img1->Get('width'), $img1->Get('height'));
                my $k = $o->{width} && ($o->{width} < $w) ? $o->{width}/$w : 1;
                $k = $o->{height}/$h if $o->{height} && (($o->{height}/$h) < $k);
                if ($k < 1) {
                    $self->debug("IMG: orig = %dx%d, k=%0.4f, new = %dx%d", $w, $h, $k, $w*$k, $h*$k);
                    $error = $img1->Resize(width=>int($w*$k), height=>int($h*$k));
                    $error && last;
                    $w = int($w*$k);
                }
                if ($o->{width} && $o->{align} && ($o->{align} =~ /right/i)) {
                    $o->{x} += $o->{width}-$w if $o->{width}>$w;
                } elsif ($o->{width} && $o->{align} && ($o->{align} =~ /center/i)) {
                    $o->{x} += int ($o->{width}-$w)/2 if $o->{width}>$w;
                }
                $error = $img->Composite(image => $img1, x=>$o->{x}, y=>$o->{y});
                $error && last;
            }
        }
        elsif ((lc($p) eq 'barcode') && $rec->{numid}) {
            my $file = "$::dirPhoto/barcode/$rec->{numid}.jpg";
            if (-f $file) { {
                my $img1 = Image::Magick->new();
                $error = $img1->Read($file);
                $error && last;
                my ($w, $h) = ($img1->Get('width'), $img1->Get('height'));
                $error = $img1->Crop(x=>0,y=>0, width=>$w, height=>int($h*0.4));
                $error && last;
                $error = $img1->Resize(width=>int($o->{width}||$w), height=>int($o->{height}||$h));
                $error && last;
                $error = $img->Composite(image => $img1, x=>$o->{x}, y=>$o->{y});
                $error && last;
            } }
        }
        
        $self->error("Image::Magick ERROR(%s): %s", $p, $error)
            if $error;
    }
    
    return $img;
}




####################################################

1;

package Func;

use strict;
use warnings;

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




####################################################

1;

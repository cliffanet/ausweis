package ImgGen;

use Clib::strict8;

use Clib::Const;
use Clib::Log;

use ImgFile;

use Image::Magick;

sub err { error(@_); return; }

####################################################

sub Save {
    my $dir = shift() || return;
    my $fname = shift() || return;
    my $ext = shift() || 'jpg';
    
    if (ref($dir) eq 'ARRAY') {
        my @dir = ImgFile::CachDir(@$dir);
        ImgFile::MakeDir(@dir) || return;
        $dir = join '/', @dir;
    }
    my $src = $dir . '/' . $fname;
    
    (-f $src) || return err('[ImgGen::Save] file not found: %s', $src);
    
    my ($prefix) = ($fname =~ /^([^.]+)\./);
    $prefix ||= $fname;
    
    foreach my $ikey (keys %{ c('imgSize') || {} }) {
        my $s = c(imgSize => $ikey);
        
        my $img = Image::Magick->new()
            || return err('[ImgGen::Save] Image::Magick->new Error');
        
        if (my $error = $img->Read($src)) {
            return err('[ImgGen::Save] Image::Magick->Read(%s): %s', $src, $error);
        }
        #if (my $error = $img->AutoOrient()) {
        #    err('[ImgGen::Save] Image::Magick->AutoOrient: %s', $error);
        #    #next;
        #}
        my ($width, $height) = ($img->Get('width'), $img->Get('height'));
        if (!$width || !$height) {
            err('[ImgGen::Save] Image::Magick: Geometry error');
            next;
        }
        
        if ($s->{width}) {
            my $k=$s->{width}/$width;
            ($width, $height) = ($s->{width}, int $height*$k);
            if (my $error = $img->Resize(width=>$width, height=>$height)) {
                err('[ImgGen::Save] Image::Magick->Resize(%d, %d): %s', $width, $height, $error);
                next;
            }
        }
        
        my $dst = $dir . '/' . join('.', $prefix, $ikey, $ext);
        if (my $error = $img->Write(
                filename => $dst, 
                compression => 'JPEG', 
                quality => 100)) {
            err('[ImgGen::Save] Image::Magick->Write(%s): %s', $dst, $error);
            next;
        }
        
        debug('[ImgGen::Save] Resized(%d x %d) \-> %s', $width, $height, $dst);
    }
    
    1;
}

####################################################

1;

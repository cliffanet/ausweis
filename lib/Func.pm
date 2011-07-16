package Func;

use strict;
use warnings;

####################################################

sub _CachDir {
    my ($type, $id) = @_;
    $id || return;
    $::dirFiles || return;
    $type ||= 'unknown';
    
    my @list = ($::dirFiles, $type);
    if (($type eq 'command') || ($type eq 'blok')) {
        $id = sprintf("%04d", $id);
        push @list, $id;
    } else {
        $id = sprintf("%06d", $id);
        push @list, $id =~ /^(\d+)(\d\d)(\d\d)$/ ? ($1, $2, $3) : $id;
    }
        
    return @list;
}

sub CachDir {
    my ($type, $id) = @_;
    return join('/', _CachDir($type, $id));
}

sub MakeCachDir {
    my ($type, $id) = @_;

    my $dir;
    foreach my $di (_CachDir($type, $id)) {    
        $dir .= "/" if $dir;
        $dir .= $di;
        if (!(-d $dir)) {
            mkdir($dir) || return;
        }
    }
        
    return 1;
}

sub SetTmpDir {
    my $self = shift;
    
    my $dir = "$::dirFiles/tmp";
    if (!(-d $dir)) {
        mkdir($dir) || return;
    }
    
    $self->req->upload_path($dir);
    
    return $self->req->upload_path();
}

sub ImgCopy {
    my ($self, $src_file, $dst_dir, $name) = @_;
    
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
    $name ||= '';
    my $file = "$name.orig.$ext";
    
    if (!open(FHO, ">$dst_dir/$file")) {
        $self->error("Can't copy photo (\-> $dst_dir/$file): $!");
        close FHI;
        return;
    }
    
    print FHO <FHI>;
    close FHO;
    close FHI;
    
    #$self->debug("Copy image $src_file \-> $dst_dir/$file");
    
    $file;
}

sub regen_stat {
    my ($self, $item) = @_;
    
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

####################################################

1;

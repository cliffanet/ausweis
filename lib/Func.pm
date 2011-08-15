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
    
    my $ext = lc $1 if $src_file =~ /\.([a-zA-Z0-9]{1,5})$/;
    $ext ||= 'jpg';
    $name ||= '';
    my $file = "$name.orig.$ext";
    
    CopyFile($self, $src_file, "$dst_dir/$file") || return;
    
    #$self->debug("Copy image $src_file \-> $dst_dir/$file");
    
    $file;
}

sub CopyFile {
    my ($self, $src, $dst) = @_;
    
    $src || return;
    if (!(-f $src)) {
        $self->error("file not found ($src)");
        return;
    }
    
    if (!open(FHI, $src)) {
        $self->error("Can't read photo file($src): $!");
        return;
    }
    if (!open(FHO, ">$dst")) {
        $self->error("Can't copy file ($src \-> $dst): $!");
        close FHI;
        return;
    }
    
    print FHO <FHI>;
    close FHO;
    close FHI;
    
    1;
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

sub dt_date {
    my ($dt) = @_;
    $dt ||= '';
    if ($dt =~ /^(\d{4})-(\d+)-(\d+)/) {
        return '' if !$1 && !$2 && !$3;
        return sprintf("%d.%s.%s", $3, $2, $1);
    }
    $dt;
}
sub dt_datetime {
    my ($dt) = @_;
    $dt ||= '';
    if ($dt =~ /^(\d{4})-(\d+)-(\d+)\s+(\d+):(\d+)/) {
        return '' if !$1 && !$2 && !$3 && !$4 && !$5;
        return sprintf("%d:%s", $4, $5) if !$1 && !$2 && !$3;
        return sprintf("%d.%s.%s %d:%s", $3, $2, $1, $4, $5);
    }
    $dt;
}


####################################################

1;

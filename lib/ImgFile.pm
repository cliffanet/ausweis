package ImgFile;

use Clib::strict8;
use Clib::Const;
use Clib::Log;
use Clib::DB::MySQL;

sub err { error(@_); return; }

####################################################

sub CachDir {
    my $type = shift() || 'unknown';
    my $id = shift()
        || return err('[ImgFile::CachDir] `id` not specified');
    
    my $dir = c('dirFiles')
        || return err('[ImgFile::CachDir] const `dirFiles` not defined');
    
    my @list = ($dir, $type);
    if (($type eq 'command') || ($type eq 'blok')) {
        $id = sprintf '%04d', $id;
        push @list, $id;
    } else {
        $id = sprintf '%06d', $id;
        my @id = ($id =~ /^(\d+)(\d\d)(\d\d)$/);
        @id = $id if !@id;
        push @list, @id;
    }
    
    return @list;
}

sub CachPath {
    return join('/', CachDir(shift(), shift()), @_);
}

sub MakeDir {
    my $dir = '';
    foreach my $d (@_) {    
        $dir .= '/' if $dir ne '';
        $dir .= $d;
        next if -d $dir;
        mkdir($dir)
            || return err('[ImgFile::MakeDir] (%s): %s', $dir, $!);
    }
        
    return 1;
}

sub MakeCachDir { return MakeDir(CachDir(@_)); }

####################################################

sub Save { # $data, $dir, $name, <составляющие_имени_файла>
    my $data = \($_[0]);
    shift();
    
    my $dir = shift() || return;
    my $name = shift() || '';
    
    my $fname = join '.', $name, @_;
    
    if (ref($dir) eq 'ARRAY') {
        my @dir = CachDir(@$dir);
        MakeDir(@dir) || return;
        $dir = join '/', @dir;
    }
    my $file = $dir . '/' . $fname;
    
    open(my $fh, '>', $file)
        || return err('[ImgFile::Save] open(%s): %s', $file, $!);
    print $fh $$data;
    close $fh;
    
    debug('[ImgFile::Save] saved %d bytes to: %s', length($$data), $file);
    
    $fname;
}

####################################################

sub RegenBit {
    my $r = 0;
    while (@_) {
        my $type = shift() || next;
        my $bnum = c(regen => $type) || next;
        my $byte = 1 << ($bnum-1);
        $r |= int $byte;
    }
    
    return $r;
}

sub RegenOff {
    my $tbl = shift() || return;
    my $id = shift() || return;
    my $r = RegenBit(@_) || return;
    
    return sqlDo(
        'UPDATE `'.$tbl.'` SET `regen` = `regen` ^ ? WHERE `id` = ?',
        $r, $id
    );
}

sub RegenName {
    my $r = int(shift()||0);
    my $n = 1;
    return
        grep {
            my $ok = $r & $n;
            $n = $n << 1;
            $ok;
        }
        @{ c('regen_name') || [] };
}

####################################################

1;

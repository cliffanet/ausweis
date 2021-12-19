package CMain::Blok;

use Clib::strict8;

##################################################

sub by_id {
    sqlGet(blok => shift());
}

sub rinfo {
    my $blok = shift();
    
    rchk('blok_info') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{blkid} || ($blok && ($user->{blkid} != $blok->{id}))) {
        rchk('blok_info_all') || return;
    }
    
    1;
}

sub redit {
    my $blok = shift();
    
    rchk('blok_edit') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{blkid} || ($blok && ($user->{blkid} != $blok->{id}))) {
        rchk('blok_edit_all') || return;
    }
    
    1;
}

sub _root :
        Simple
{
    rchk('blok_list') || return 'rdenied';
    my $p = wparam();
    
    my @query = ();
    my @where = ();
    my $noblock_count = 0;
    
    if ($p->exists('srch') && length($p->str('srch'))) {
        my $s = $p->str('srch');
        
        push @query, srch => $s;
        
        $s =~ s/([%_])/\\$1/g;
        $s =~ s/\*/%/g;
        $s =~ s/\?/_/g;
        $s = '%'.$s if $s !~ /^%/;
        $s .= '%' if $s !~ /%$/;
        #$s .= '%' if $s !~ /^(.*[^\\])?%$/;
        push @where, sqlLike(name => $s);
    }
    else {
        $noblock_count = sqlSrch(command => blkid => 0 );
    }

    my @list = sqlSrch(blok => @where, sqlOrder('name'));
    
    $_->{cmdcount} = 0 foreach @list;
    my %byid = map { ($_->{id} => $_) } @list;
    if (%byid) {
        foreach my $cmd (sqlSrch(command => blkid => [keys %byid])) {
            my $blk = $byid{ $cmd->{blkid} } || next;
            $blk->{cmdcount} ++;
        }
    }
    
    return
        'blok_list',
        srch    => $p->str('srch'),
        qsrch   => qsrch([qw/srch/], @query),
        noblock_count => $noblock_count,
        list    => \@list,
}

sub srch :
        ReturnBlock
{
    my ($tmpl, @p) = _root();
    return
        $tmpl => 'CONTENT_result',
        @p;
}

sub info :
        ParamCodeUInt(\&by_id)
{
    my $blok = shift();
    
    rinfo($blok) || return 'rdenied';
    $blok || return 'notfound';
    
    my $filelogo = 'logo.site.jpg';
    my $filesize = -s ImgFile::CachPath(blok => $blok->{id}, $filelogo);
    
    my @cmd = sqlSrch(command => blkid => $blok->{id}, sqlOrder('name'));
    
    return
        'blok_info',
        blok            => $blok,
        file_logo       => $filelogo,
        file_logo_size  => $filesize,
        regen           => [ImgFile::RegenName($blok->{regen})],
        cmd_list        => \@cmd,
}

sub my :
        Simple
{
    my $user = WebMain::auth('user') || return 'rdenied';
    my $blkid = $user->{blkid} || return 'notfound';
    my $blok = by_id($blkid) || return 'notfound';
    
    return info($blok);
}

sub edit :
        ParamCodeUInt(\&by_id)
{
    my $blok = shift();
    
    redit($blok) || return 'rdenied';
    $blok || return 'notfound';
    editable() || return 'readonly';
    
    return
        'blok_edit',
        blok    => $blok,
        form($blok);
}

sub file :
        ParamCodeUInt(\&by_id)
        ParamRegexp('[a-zA-Z\d\.\-]+')
        ParamEnd # ссылку будет завершать не имя функции "file", а само имя файла из аргументов
        ReturnFile
{
    my $blok = shift();
    
    rinfo($blok) || return 'rdenied';
    $blok || return 'notfound';
    
    return ImgFile::CachPath(blok => $blok->{id}, 'logo.site.jpg');
}

sub adding :
        Simple
{
    rchk('blok_edit_all') || return 'rdenied';
    editable() || return 'readonly';
    
    return
        'blok_add',
        form(qw/name/);
}

# Загрузка логотипа
sub _logo_load {
    my $blkid = shift();
    defined($_[0]) || return 1;
    
    my $p = wparam();
    my $ext = $p->str('photo') =~ /\.([a-zA-Z0-9]{1,5})$/ ? lc($1) : 'jpg';
    my $fname = ImgFile::Save($_[0], [blok => $blkid], logo => orig => $ext)
        || return;
    
    sqlUpd(
        blok => $blkid,
        regen   => ImgFile::RegenBit('logo'),
        photo   => $fname
    ) || return;
    
    return 1;
}

sub add :
        ReturnOperation
{
    rchk('blok_edit_all') || return err => 'rdenied';
    editable() || return err => 'readonly';
    
    my $logo;
    my $p = wparam(file => { photo => \$logo });
    my %err = ();
    my @new = ();
    
    # Проверка данных
    if ($p->exists('name')) {
        my $name = $p->str('name');
        push @new, name => $name;
        
        if ($name eq '') {
            $err{name} = 'empty';
        }
    }
    else {
        $err{name} = 'nospec';
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => 'blok/adding';
    }
    
    # Сохраняем
    my $blkid = sqlAdd(blok => @new)
        || return
            err  => 'db',
            ferr => \%err,
            pref => 'blok/adding';
    
    # Загрузка логотипа
    _logo_load($blkid, $logo)
        || return
            err  => 'imgload',
            pref => ['blok/edit', $blkid];
        
    return
        ok => 1,
        pref => ['blok/info', $blkid];
}

sub set :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $blok = shift();
    
    redit($blok) || return err => 'rdenied';
    $blok || return err => 'notfound';
    editable() || return err => 'readonly';
    
    my $logo;
    my $p = wparam(file => { photo => \$logo });
    my %err = ();
    my @upd = ();
    
    # Проверка данных
    if ($p->exists('name')) {
        my $name = $p->str('name');
        push(@upd, name => $name) if $name ne $blok->{name};
        
        if ($name eq '') {
            $err{name} = 'empty';
        }
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => ['blok/edit' => $blok->{id}];
    }
    
    # Надо ли, что сохранять
    if (@upd) {
        # Сохраняем
        sqlUpd(blok => $blok->{id}, @upd)
            || return
                err  => 'db',
                ferr => \%err,
                pref => ['blok/edit' => $blok->{id}];
    }
    elsif (!defined($logo)) {
        return err => 'nochange', pref => ['blok/edit' => $blok->{id}];
    }
    
    # Загрузка логотипа
    _logo_load($blok->{id}, $logo)
        || return
            err  => 'imgload',
            pref => ['blok/edit', $blok->{id}];
        
    return
        ok => 1,
        pref => ['blok/info' => $blok->{id}];
}

sub del :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $blok = shift();
    
    redit($blok) || return err => 'rdenied';
    $blok || return err => 'notfound';
    editable() || return err => 'readonly';
    
    sqlDel(blok => $blok->{id})
        || return
            err  => 'db',
            pref => '';
    
    foreach my $cmd (sqlSrch(command => blkid => $blok->{id})) {
        sqlUpd(command => $cmd->{id}, blkid => 0)
            || return
                err  => 'db',
                pref => '';
    }
    
    foreach my $aus (sqlSrch(ausweis => blkid => $blok->{id})) {
        sqlUpd(ausweis => $aus->{id}, blkid => 0)
            || return
                err  => 'db',
                pref => '';
    }
    
    return
        ok => 1,
        pref => 'blok';
}

1;

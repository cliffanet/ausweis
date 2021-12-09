package CMain::Admin;

use Clib::strict8;

sub user_by_id {
    sqlGet(user_list => shift());
}

sub _root :
        Simple
{
    rchk('admin_read') || return 'rdenied';
    my $p = wparam();
    
    my @grp = sqlSrch(user_group => sqlOrder('name'));
    my %grp = map { ($_->{id} => $_) } @grp;
    
    my @query = ();
    my @where = ();
    
    if ($p->exists('srch') && length($p->str('srch'))) {
        my $s = $p->str('srch');
        
        push @query, srch => $s;
        
        $s =~ s/([%_])/\\$1/g;
        $s =~ s/\*/%/g;
        $s =~ s/\?/_/g;
        $s = '%'.$s if $s !~ /^%/;
        $s .= '%' if $s !~ /%$/;
        #$s .= '%' if $s !~ /^(.*[^\\])?%$/;
        my @cmd =
            map { $_->{id} }
            sqlSrch(command => sqlLike(name => $s));
        push @where, @cmd ?
            sqlOr(sqlLike(login => $s), cmdid => @cmd > 1 ? [@cmd] : $cmd[0]) :
            sqlLike(login => $s);
    }

    my $group;
    if ($p->exists('gid')) {
        my $gid = $p->uint('gid');
        push @query, gid => $gid;
        push @where, gid => $gid;
        $group = sqlGet(user_group => $gid);
    }
    
    my $pager = { onpage => 100 };
    my @user = sqlSrch(user_list => @where, $pager, sqlOrder('login'));
    
    my %cmd = map { ($_->{cmdid} => 1) } @user;
    if (%cmd) {
        %cmd =
            map { ($_->{id} => $_) }
            sqlGet(command => [keys %cmd]);
    }
    
    foreach my $u (@user) {
        $u->{group} = $grp{ $u->{gid} };
        $u->{command} = $cmd{ $u->{cmdid} };
    }
    
    return
        'admin_list',
        srch    => $p->str('srch'),
        qsrch   => qsrch([qw/srch gid/], @query),
        group   => $group,
        pager   => $pager,
        ulist   => \@user,
        glist   => \@grp,
}

sub srch :
        ReturnBlock
{
    my ($tmpl, @p) = _root();
    return
        $tmpl => 'CONTENT_result',
        @p;
}


sub uadding :
        Simple
{
    rchk('admin_write') || return 'rdenied';
    editable() || return 'readonly';
    
    my @grp = sqlAll(user_group => 'name');
    my @cmd = sqlAll(command => 'name');
    
    my %blok =
        map { ($_->{id} => $_) }
        sqlAll('blok');
    foreach my $cmd (@cmd) {
        my $blkid = $cmd->{blkid} || next;
        $cmd->{blok} = $blok{ $blkid };
    }
    
    return
        'admin_uadd',
        form(qw/login gid cmdid/),
        group_list  => \@grp,
        cmd_list    => \@cmd;
}

sub uadd :
        ReturnOperation
{
    rchk('admin_write') || return err => 'rdenied';
    editable() || return err => 'readonly';

    my $p = wparam();
    my %err = ();
    my @new = ();
    
    # Проверка данных
    if ($p->exists('login')) {
        my $login = $p->str('login');
        push @new, login => $login;
        
        if ($login !~ /^[a-zA-Z_0-9\-а-яА-Я]+$/) {
            $err{login} = 'format';
        }
        elsif (sqlSrch(user_list => login => $login)) {
            $err{login} = 'used';
        }
    }
    else {
        $err{login} = 'nospec';
    }
    
    if ($p->exists('ps')) {
        my $pass = $p->raw('ps');
        $pass = '' if !defined($pass);
        push @new, password => [PASSWORD => $pass];
        
        if ($pass eq '') {
            $err{password} = 'empty';
        }
        elsif ($p->exists('p2')) {
            my $pass2 = $p->raw('p2');
            if (!defined($pass2) || ($pass2 ne $pass)) {
                $err{pass2} = 'passconfirm';
            }
        }
    }
    else {
        $err{password} = 'nospec';
    }
    
    if ($p->exists('gid')) {
        my $gid = $p->uint('gid');
        push @new, gid => $gid;
        
        if ($p->str('gid') !~ /^\d+$/) {
            $err{gid} = 'format';
        }
        elsif ($gid && !sqlGet(user_group => $gid)) {
            $err{gid} = 'novalid';
        }
    }
    
    if ($p->exists('cmdid')) {
        my $cmdid = $p->uint('cmdid');
        push @new, cmdid => $cmdid;
        
        if ($p->str('cmdid') !~ /^\d+$/) {
            $err{cmdid} = 'format';
        }
        elsif ($cmdid && !sqlGet(command => $cmdid)) {
            $err{cmdid} = 'novalid';
        }
    }
    
    push @new, rights => Clib::Rights::GROUP x 128;
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => 'admin/uadding';
    }
    
    # Сохраняем
    my $uid = sqlAdd(user_list => @new)
        || return
            err  => 'db',
            ferr => \%err,
            pref => 'admin/uadding';
        
    return
        ok => 1,
        pref => 'admin';
}

sub uedit :
        ParamCodeUInt(\&user_by_id)
{
    my $user = shift();
    
    rchk('admin_write') || return 'rdenied';
    $user || return 'notfound';
    editable() || return 'readonly';
    
    my $grp = $user->{gid} ? sqlGet(user_group => $user->{gid}) : undef;
    
    my @urights = split(//, $user->{rights});
    my @grights = $grp ? split(//, $grp->{rights}) : ();
    
    my %rByCode = map { ($_->[1] => $_->[2]) } @{ c('rtypes')||[] };
    my %rBySymb = map { ($_->[0] => $_->[1]) } @{ c('rtypes')||[] };
    
    my @grp = sqlAll(user_group => 'name');
    my @cmd = sqlAll(command => 'name');
    
    my %blok =
        map { ($_->{id} => $_) }
        sqlAll('blok');
    foreach my $cmd (@cmd) {
        my $blkid = $cmd->{blkid} || next;
        $cmd->{blok} = $blok{ $blkid };
    }
    
    my %form = form($user);
    my %f = %{ $form{form}||{} };
    
    my @rights =
        map {
            if (ref($_) eq 'ARRAY') {
                my ($vname, $num, $name, @var) = @$_;
                my $ur = $urights[$num];
                $ur = Clib::Rights::DENY if !defined($ur) || ($ur eq '');
                my $gr = $grights[$num];
                $gr = Clib::Rights::DENY if !defined($gr) || ($gr eq '');
                my $fname = sprintf('rights_%d', $num); # имя поля
                {
                    vname   => $vname,
                    num     => $num,
                    name    => $name,
                    fname   => $fname,
                    ucode   => exists $f{$fname} ? $f{$fname} : $ur,
                    uvar    => { code => $ur, name => $rByCode{$ur}||$ur },
                    gvar    => { code => $gr, name => $rByCode{$gr}||$gr },
                    var_list=> [
                        map { { code => $rBySymb{$_}||$_, name => $rByCode{$rBySymb{$_}||$_}||$_ } } @var
                    ],
                    err     => ($form{ferr}||{})->{$fname},
                }
            }
            else {
                undef
            }
        }
        @{ c('rights')||[] };
    
    return
        'admin_uedit',
        usr => $user,
        %form,
        group_list  => \@grp,
        cmd_list    => \@cmd,
        dcode => Clib::Rights::DENY,
        gcode => Clib::Rights::GROUP,
        rights_list => \@rights;
}

sub uset :
        ParamCodeUInt(\&user_by_id)
        ReturnOperation
{
    my $user = shift();
    
    rchk('admin_write') || return err => 'rdenied';
    $user || return err => 'notfound';
    editable() || return err => 'readonly';

    my $p = wparam();
    my %err = ();
    my @upd = ();
    
    # Проверка данных
    if ($p->exists('login')) {
        my $login = $p->str('login');
        push(@upd, login => $login) if $login ne $user->{login};
        
        if ($login !~ /^[a-zA-Z_0-9\-а-яА-Я]+$/) {
            $err{login} = 'format';
        }
        elsif (sqlSrch(user_list => login => $login, sqlNotEq(id => $user->{id}))) {
            $err{login} = 'used';
        }
    }
    
    if ($p->exists('ps') && ($p->raw('ps') ne '')) {
        my $pass = $p->raw('ps');
        push @upd, password => [PASSWORD => $pass];
        
        if ($p->exists('p2')) {
            my $pass2 = $p->raw('p2');
            if (!defined($pass2) || ($pass2 ne $pass)) {
                $err{pass2} = 'passconfirm';
            }
        }
    }
    
    if ($p->exists('gid')) {
        my $gid = $p->uint('gid');
        push(@upd, gid => $gid) if $gid != $user->{gid};
        
        if ($p->str('gid') !~ /^\d+$/) {
            $err{gid} = 'format';
        }
        elsif ($gid && !sqlGet(user_group => $gid)) {
            $err{gid} = 'novalid';
        }
    }
    
    if ($p->exists('cmdid')) {
        my $cmdid = $p->uint('cmdid');
        push(@upd, cmdid => $cmdid) if $cmdid != $user->{cmdid};
        
        if ($p->str('cmdid') !~ /^\d+$/) {
            $err{cmdid} = 'format';
        }
        elsif ($cmdid && !sqlGet(command => $cmdid)) {
            $err{cmdid} = 'novalid';
        }
    }
    
    if ($p->exists('email')) {
        my $email = $p->str('email');
        push(@upd, email => $email) if $email ne $user->{email};
        
        if ($email && ($email !~ /^[a-zA-Z_0-9][a-zA-Z_0-9\-\.]*\@[a-zA-Z0-9\_\-]+\.[a-zA-Z0-9]{1,4}$/)) {
            $err{email} = 'format';
        }
    }
    
    # Права
    my $rights = $user->{rights};
    my %rBySymb = map { ($_->[0] => $_->[1]) } @{ c('rtypes')||[] };
    foreach (grep { ref($_) eq 'ARRAY' } @{ c('rights')||[] }) {
        my (undef, $num, $name, @var) = @$_;
        my $fname = sprintf('rights_%d', $num); # имя поля
        my $rval = $p->raw($fname);
        defined($rval) || next;
        if (length($rval) != 1) {
            $err{$fname} = 'format';
            next;
        }
        if (!(grep { $rval eq $_ } (Clib::Rights::DENY, Clib::Rights::GROUP, map { $rBySymb{$_}||$_ } @var))) {
            $err{$fname} = 'novalid';
            next;
        }
        
        $rights = Clib::Rights::set($rights, $num, $rval, 1);
    }
    push(@upd, rights => $rights) if $rights ne $user->{rights};
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => ['admin/uedit' => $user->{id}];
    }
    
    # Надо ли, что сохранять
    @upd || return err => 'nochange', pref => ['admin/uedit' => $user->{id}];
    
    # Сохраняем
    my $uid = sqlUpd(user_list => $user->{id}, @upd)
        || return
            err  => 'db',
            ferr => \%err,
            pref => ['admin/uedit' => $user->{id}];
        
    return
        ok => 1,
        pref => 'admin';
}

sub udel :
        ParamCodeUInt(\&user_by_id)
        ReturnOperation
{
    my $user = shift();
    
    rchk('admin_write') || return err => 'rdenied';
    $user || return err => 'notfound';
    editable() || return err => 'readonly';

    my $uid = sqlDel(user_list => $user->{id})
        || return
            err  => 'db',
            pref => '';
        
    return
        ok => 1,
        pref => 'admin';
}



=pod   
sub gadding :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('admin_write') || return;
    $self->view_can_edit() || return;
    $self->template("admin_gadd");
    
    # Автозаполнение полей, если данные из формы не приходили
    my $form =
        { map { ($_ => '') } qw/name/ };
    if ($self->req->params()) {
            _utf8_on($form->{$_} = $self->req->param($_)) foreach $self->req->params();
    }
    return
        form => $form,
        ferror => $self->FormError(),
}
        
sub gadd :
        ReturnOperation
{
    my ($self) = @_;
    
    $self->rcheck('admin_write') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    
    my %err = ();
    my %new = ();
    my $q = $self->req;
    
    foreach my $p (qw/name/) {
        _utf8_on($new{$p} = $q->param_str($p))
            if defined $q->param($p);
    }
    
    # Проверка данных
    if (exists($new{name})) {
        if ($new{name} eq '') {
            $err{name} = 1;
        }
        elsif ($self->model('UserGroup')->count({ name => $new{name} })) {
            $err{name} = 6;
        }
    }
    else {
        $err{name} = 1;
    }
    
    # Ошибки заполнения формы
    my @fpar = (qw/name/);
    if (%err) {
        return (error => 000101, pref => 'admin/gadding', fpar => \@fpar, ferr => \%err);
    }
    
    # Сохраняем
    $self->model('UserGroup')->create(\%new)
        || return (error => 000104, pref => 'admin/gadding', fpar => \@fpar, ferr => \%err);
        
    return (ok => 20200, pref => 'admin');
}


sub gedit :
        ParamObj('grp', 0)
        ReturnPatt
{
    my ($self, $grp) = @_;
    
    $self->view_rcheck('admin_read') || return;
    $grp || return $self->notfound;
    $self->view_can_edit() || return;
    $self->template('admin_gedit');
    
    my @grights = split(//, $grp->{rights});
    
    my %rByCode = map { ($_->[1] => $_->[2]) } @{ $self->c('rtypes')||[] };
    my %rBySymb = map { ($_->[0] => $_->[1]) } @{ $self->c('rtypes')||[] };
    
    my %form = %$grp;
    if ($self->req->params()) {
        _utf8_on($form{$_} = $self->req->param($_)) foreach $self->req->params();
    }
    
    return
        grp  => $grp,
        form => \%form,
        ferror => $self->FormError(),
        dcode => RIGHT_DENY,
        rights_list => [
            map {
                if (ref($_) eq 'ARRAY') {
                    my ($vname, $num, $name, @var) = @$_;
                    my $gr = $grights[$num];
                    $gr = RIGHT_DENY if !defined($gr) || ($gr eq '');
                    my $fname = sprintf('rights.%d', $num); # имя поля
                    {
                        vname   => $vname,
                        num     => $num,
                        name    => $name,
                        fname   => $fname,
                        gcode   => exists $form{$fname} ? $form{$fname} : $gr,
                        gvar    => { code => $gr, name => $rByCode{$gr}||$gr },
                        var_list=> [
                            map { { code => $rBySymb{$_}||$_, name => $rByCode{$rBySymb{$_}||$_}||$_ } } @var
                        ],
                    }
                }
                else {
                    undef
                }
            }
            @{ $self->c('rights')||[] }
        ],
}
        
sub gset :
        ParamObj('grp', 0)
        ReturnOperation
{
    my ($self, $grp) = @_;
    
    $self->rcheck('admin_write') || return $self->rdenied;
    $grp || return $self->notfound;
    $self->d->{read_only} && return $self->cantedit();
    
    my %err = ();
    my %upd = ();
    my $q = $self->req;
    
    foreach my $p (qw/name/) {
        _utf8_on($upd{$p} = $q->param_str($p))
            if defined $q->param($p);
    }
    
    # Проверка данных
    if (exists($upd{name})) {
        if ($upd{name} eq '') {
            $err{name} = 1;
        }
        elsif ($self->model('UserGroup')->count({ name => $upd{name}, id => { '!=' => $grp->{id} } })) {
            $err{name} = 6;
        }
    }
    
    # Права
    $upd{rights} = $grp->{rights};
    my %rBySymb = map { ($_->[0] => $_->[1]) } @{ $self->c('rtypes')||[] };
    foreach (grep { ref($_) eq 'ARRAY' } @{ $self->c('rights')||[] }) {
        my (undef, $rnum, $name, @vals) = @$_;
        my $f = "rights.$rnum";
        my $rval = $q->param($f);
        defined($rval) || next;
        if (length($rval) != 1) {
            $err{$f} = 2;
            next;
        }
        if (!(grep { $rval eq $_ } (RIGHT_DENY, map { $rBySymb{$_}||$_ } @vals))) {
            $err{$f} = 5;
            next;
        }
        
        $upd{rights} = Clib::Rights::rights_Set($upd{rights}, $rnum, $rval);
    }
    
    # Ошибки заполнения формы
    my @fpar = (qw/name/, map { 'rights.'.$_->[1] } grep { ref($_) eq 'ARRAY' } @{ $self->c('rights')||[] });
    if (%err) {
        return (error => 000101, pref => ['admin/gedit' => $grp->{id}], fpar => \@fpar, ferr => \%err);
    }
    
    # Убираем из списка неизменившиеся поля
    foreach my $p (keys %upd) {
        delete($upd{$p})
            if $upd{$p} eq $grp->{$p};
    }
    
    # Осталось ли, что сохранять
    %upd || return ( error => 000106, pref => ['admin/gedit' => $grp->{id}]);
    
    # Сохраняем
    $self->model('UserGroup')->update(\%upd, { id => $grp->{id} })
        || return (error => 000104, pref => ['admin/gedit' => $grp->{id}], fpar => \@fpar, ferr => \%err);
        
    return (ok => 20400, pref => 'admin');
}
        
sub gdel :
    ParamObj('grp', 0)
    ReturnOperation
{
    my ($self, $grp) = @_;
    
    $self->rcheck('admin_write') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $grp || return $self->nfound();
    $self->d->{read_only} && return $self->cantedit();
    
    $self->model('UserList')->update({ gid => 0 }, { gid => $grp->{id} })
        || return (error => 000104, href => '');
    
    $self->model('UserGroup')->delete({ id => $grp->{id} })
        || return (error => 000104, href => '');
    
    # статус с редиректом
    return (ok => 20600, pref => 'admin');
}
=cut

1;

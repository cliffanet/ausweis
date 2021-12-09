package CMain::Admin;

use Clib::strict8;


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
        group_list  => \@grp,
        cmd_list    => \@cmd,
        form(qw/login gid cmdid/);
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



=pod
sub uedit :
        ParamObj('user', 0)
        ReturnPatt
{
    my ($self, $user) = @_;
    
    $self->view_rcheck('admin_read') || return;
    $user || return $self->notfound;
    $self->view_can_edit() || return;
    $self->template('admin_uedit');
    
    my $grp;
    $grp = $self->model('UserGroup')->byId($user->{gid}) if $user->{gid};
    
    my @urights = split(//, $user->{rights});
    my @grights = $grp ? split(//, $grp->{rights}) : ();
    
    my %rByCode = map { ($_->[1] => $_->[2]) } @{ $self->c('rtypes')||[] };
    my %rBySymb = map { ($_->[0] => $_->[1]) } @{ $self->c('rtypes')||[] };
    
    my %form = %$user;
    if ($self->req->params()) {
        _utf8_on($form{$_} = $self->req->param($_)) foreach $self->req->params();
    }
    
    return
        usr => $user,
        form => \%form,
        ferror => $self->FormError(),
        group_list => [ $self->model('UserGroup')->search({}, { order_by => 'name'}) ],
        dcode => RIGHT_DENY,
        gcode => RIGHT_GROUP,
        rights_list => [
            map {
                if (ref($_) eq 'ARRAY') {
                    my ($vname, $num, $name, @var) = @$_;
                    my $ur = $urights[$num];
                    $ur = RIGHT_DENY if !defined($ur) || ($ur eq '');
                    my $gr = $grights[$num];
                    $gr = RIGHT_DENY if !defined($gr) || ($gr eq '');
                    my $fname = sprintf('rights.%d', $num); # имя поля
                    {
                        vname   => $vname,
                        num     => $num,
                        name    => $name,
                        fname   => $fname,
                        ucode   => exists $form{$fname} ? $form{$fname} : $ur,
                        uvar    => { code => $ur, name => $rByCode{$ur}||$ur },
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
        
        cmd_list=> [ $self->model('Command')->search({}, { prefetch => 'blok', order_by => 'name'}) ],
}
        
sub uset :
        ParamObj('user', 0)
        ReturnOperation
{
    my ($self, $user) = @_;
    
    $self->rcheck('admin_write') || return $self->rdenied;
    $user || return $self->notfound;
    $self->d->{read_only} && return $self->cantedit();
    
    my %err = ();
    my %upd = ();
    my $q = $self->req;
    
    foreach my $p (qw/login email/) {
        _utf8_on($upd{$p} = $q->param_str($p))
            if defined $q->param($p);
    }
    foreach my $p (qw/gid cmdid/) {
        $upd{$p} = $q->param_int($p)
            if defined $q->param($p);
    }
    
    # Проверка данных
    if (exists($upd{login})) {
        if ($upd{login} !~ /^[a-zA-Z_0-9\-а-яА-Я]+$/) {
            $err{login} = 2;
        }
        elsif ($self->model('UserList')->count({ login => $upd{login}, id => { '!=' => $user->{id} } })) {
            $err{login} = 6;
        }
    }
    
    my $pass = $q->param('ps');
    if (defined($pass) && ($pass ne '')) {
        my $pass2 = $q->param('p2');
        foreach my $s ($pass, $pass2) {
            _utf8_on($s);
        }
        if (!defined($pass2) || ($pass eq $pass2)) {
            $upd{password} = { PASSWORD => $pass };
        }
        else {
            $err{password} = 4;
        }
    }
    
    if (exists($upd{gid})) {
        if ($upd{gid} < 0) {
            $err{gid} = 2;
        }
        elsif ($upd{gid} && !$self->model('UserGroup')->count({ id => $upd{gid} })) {
            $err{gid} = 5;
        }
    }
    
    if (exists($upd{cmdid})) {
        if ($upd{cmdid} < 0) {
            $err{cmdid} = 2;
        }
        elsif ($upd{cmdid} && !$self->model('Command')->count({ id => $upd{cmdid} })) {
            $err{cmdid} = 5;
        }
    }
    
    if (exists($upd{email})) {
        if ($upd{email} && ($upd{email} !~ /^[a-zA-Z_0-9][a-zA-Z_0-9\-\.]*\@[a-zA-Z0-9\_\-]+\.[a-zA-Z0-9]{1,4}$/)) {
            $err{email} = 2;
        }
    }
    
    # Права
    $upd{rights} = $user->{rights};
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
        if (!(grep { $rval eq $_ } (RIGHT_DENY, RIGHT_GROUP, map { $rBySymb{$_}||$_ } @vals))) {
            $err{$f} = 5;
            next;
        }
        
        $upd{rights} = Clib::Rights::rights_Set($upd{rights}, $rnum, $rval, 1);
    }
    
    # Ошибки заполнения формы
    my @fpar = (qw/login password gid cmdid email/, map { 'rights.'.$_->[1] } grep { ref($_) eq 'ARRAY' } @{ $self->c('rights')||[] });
    if (%err) {
        return (error => 000101, pref => ['admin/uedit' => $user->{id}], fpar => \@fpar, ferr => \%err);
    }
    
    # Убираем из списка неизменившиеся поля
    foreach my $p (keys %upd) {
        delete($upd{$p})
            if $upd{$p} eq $user->{$p};
    }
    
    # Осталось ли, что сохранять
    %upd || return ( error => 000106, pref => ['admin/uedit' => $user->{id}]);
    
    # Сохраняем
    $self->model('UserList')->update(\%upd, { id => $user->{id} })
        || return (error => 000104, pref => ['admin/uedit' => $user->{id}], fpar => \@fpar, ferr => \%err);
        
    return (ok => 20300, pref => 'admin');
}
        
sub udel :
    ParamObj('user', 0)
    ReturnOperation
{
    my ($self, $user) = @_;
    
    $self->rcheck('admin_write') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    $user || return $self->nfound();
    $self->d->{read_only} && return $self->cantedit();
    
    $self->model('UserList')->delete({ id => $user->{id} })
        || return (error => 000104, href => '');
    
    # статус с редиректом
    return (ok => 20500, pref => 'admin');
}


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

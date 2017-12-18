package C::Admin;
use strict;
use warnings;

use Clib::Rights;

use Encode '_utf8_on', 'encode';
use utf8;


sub _root :
        ReturnPatt
{
    my $self = shift;
    
    $self->view_rcheck('admin_read') || return;
    $self->template('admin_list', 'CONTENT_result');
    
    my @group = $self->model('UserGroup')->search({}, { order_by => 'name' });
    my %grp = map { ($_->{id} => $_) } @group;
    
    my @qsrch = ();
    my $srch = {};
    my $s = $self->req->param_str('srch');
    _utf8_on($s);
    push @qsrch, { f => 'srch', val => $s };
    if (my $name = $s) {
        $name =~ s/([%_])/\\$1/g;
        $name =~ s/\*/%/g;
        $name =~ s/\?/_/g;
        $name = "%$name" if $name !~ /^%/;
        $name .= "%" if $name !~ /%$/;
        #$name .= "%" if $name !~ /^(.*[^\\])?%$/;
        $srch->{-or} = {
            login           => { LIKE => $name },
            'command.name'  => { LIKE => $name },
        };
    }
    
    my $gid = $self->req->param_dig('gid');
    push @qsrch, { f => 'gid', val => $gid };
    my $group;
    if ($gid) {
        $srch->{gid} = $gid > 0 ? $gid : 0;
        if ($gid > 0) {
            $group = $self->model('UserGroup')->byId($gid);
        }
    }
    
    my ($count, $countall);
    my @user =
        map {
            $_->{group} = $grp{ $_->{gid} };
            $_;
        }
        $self->model('UserList')->search(
            $srch,
            {
                prefetch => 'command',
                order_by => [qw/login/],
            },
            pager => {
                onpage => 100,
                handler => sub {
                    my %p = @_;
                    $count = $p{count};
                    $countall = $p{countall};
                },
            },
        );
    
    return
        srch    => $s,
        qsrch => $self->qsrch(@qsrch),
        gid     => $gid,
        group   => $group,
        count   => $count,
        countall=> $countall,
        ulist   => \@user,
        glist   => \@group,
}


sub uadding :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('admin_write') || return;
    $self->view_can_edit() || return;
    $self->template("admin_uadd");
    
    # Автозаполнение полей, если данные из формы не приходили
    my $form =
        { map { ($_ => '') } qw/login password gid cmdid/ };
    if ($self->req->params()) {
            _utf8_on($form->{$_} = $self->req->param($_)) foreach $self->req->params();
    }
    return
        form => $form,
        ferror => $self->FormError(),
        group_list => [ $self->model('UserGroup')->search({}, { order_by => 'name'}) ],
        cmd_list=> [ $self->model('Command')->search({}, { prefetch => 'blok', order_by => 'name'}) ],
}
        
sub uadd :
        ReturnOperation
{
    my ($self) = @_;
    
    $self->rcheck('admin_write') || return $self->rdenied;
    
    my %err = ();
    my %new = ();
    my $q = $self->req;
    
    foreach my $p (qw/login/) {
        _utf8_on($new{$p} = $q->param_str($p))
            if defined $q->param($p);
    }
    foreach my $p (qw/gid cmdid/) {
        $new{$p} = $q->param_int($p)
            if defined $q->param($p);
    }
    
    # Проверка данных
    if (exists($new{login})) {
        if ($new{login} !~ /^[a-zA-Z_0-9\-а-яА-Я]+$/) {
            $err{login} = 2;
        }
        elsif ($self->model('UserList')->count({ login => $new{login} })) {
            $err{login} = 6;
        }
    }
    else {
        $err{login} = 1;
    }
    
    my $pass = $q->param('ps');
    if (defined($pass) && ($pass ne '')) {
        my $pass2 = $q->param('p2');
        foreach my $s ($pass, $pass2) {
            _utf8_on($s);
        }
        if (!defined($pass2) || ($pass eq $pass2)) {
            $new{password} = { PASSWORD => $pass };
        }
        else {
            $err{password} = 4;
        }
    }
    else {
        $err{password} = 1;
    }
    
    if (exists($new{gid})) {
        if ($new{gid} < 0) {
            $err{gid} = 2;
        }
        elsif ($new{gid} && !$self->model('UserGroup')->count({ id => $new{gid} })) {
            $err{gid} = 5;
        }
    }
    
    if (exists($new{cmdid})) {
        if ($new{cmdid} < 0) {
            $err{cmdid} = 2;
        }
        elsif ($new{cmdid} && !$self->model('Command')->count({ id => $new{cmdid} })) {
            $err{cmdid} = 5;
        }
    }
    
    $new{rights} = RIGHT_GROUP x 128;
    
    # Ошибки заполнения формы
    my @fpar = (qw/login password gid cmdid/);
    if (%err) {
        return (error => 000101, pref => 'admin/uadding', fpar => \@fpar, ferr => \%err);
    }
    
    # Сохраняем
    $self->model('UserList')->create(\%new)
        || return (error => 000104, pref => 'admin/uadding', fpar => \@fpar, ferr => \%err);
        
    return (ok => 20100, pref => 'admin');
}


sub uedit :
        ParamObj('user', 0)
        ReturnPatt
{
    my ($self, $user) = @_;
    
    $self->view_rcheck('admin_read') || return;
    $user || return $self->notfound;
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
    
    $self->model('UserList')->update({ gid => 0 }, { gid => $grp->{id} })
        || return (error => 000104, href => '');
    
    $self->model('UserGroup')->delete({ id => $grp->{id} })
        || return (error => 000104, href => '');
    
    # статус с редиректом
    return (ok => 20600, pref => 'admin');
}
    

1;

#!/bin/sh
#
# $FreeBSD: main (ausweis), v1.5 2007/09/30 23:10:55 flood Exp 
#
# PROVIDE: cliff
# REQUIRE: NETWORKING
#
# Add the following line to /etc/rc.conf to enable ausweis_main:
#
# ausweis_main_enable="YES"
#

ausweis_main_enable="${ausweis_main_enable-NO}"
. /etc/rc.subr


name=ausweis_main
rcvar=`set_rcvar`

prefix=/home/ausweis
procname=fcgi-ausweis-main
pidfile=/var/run/ausweis/main.fcgi.pid
required_files="${prefix}/redefine.conf"
command="${prefix}/fcgi/main"

load_rc_config ${name}

run_rc_command "$1"

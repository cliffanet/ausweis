#!/bin/sh

d='../texcel'

if [ "x$1" != "x" ]; then
    d=$1
fi

list=`ls $d | grep -s  ".cp1251$" | grep -s -o -e "^[^.]*"`

for f in $list; do
    iconv  -f cp1251 -t utf-8 $d/${f}.cp1251 > $d/${f}.xt
done
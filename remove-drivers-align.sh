#!/bin/bash

f=src/drivers/Makefile
git checkout-index -q -f -- $f

[[ -f $f ]] || exit 0

< $f sed "s:filter-out align:filter-out:g" | grep -v '= align' > $f.tmp
mv -Tf $f.tmp $f
git update-index -- $f
rm -f $f

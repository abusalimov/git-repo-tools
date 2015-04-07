#!/bin/bash

f=src/drivers/Makefile
git checkout-index -q -f -- $f

[[ -f $f ]] || exit 0

< $f grep -v '= flash' > $f.tmp
mv -Tf $f.tmp $f
git update-index -- $f
rm -f $f

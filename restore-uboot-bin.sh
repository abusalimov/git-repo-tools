#!/bin/bash

f=scripts/qemu/beagle/x-load.bin.ift
git checkout-index -q -f -- scripts/qemu/beagle/x-load.bin.ift
[[ -f $f ]] || exit 0
rm -fv $f

files="scripts/qemu/beagle/u-boot.bin \
	scripts/qemu/beagle/uboot_env_16m.bin \
	scripts/qemu/beagle/uboot_env_2m.bin \
	scripts/qemu/beagle/uboot_env_4m.bin \
	scripts/qemu/beagle/uboot_env_8m.bin \
	scripts/qemu/beagle/uboot_env_1m.bin \
	scripts/qemu/beagle/uboot_env_32m.bin \
	scripts/qemu/beagle/uboot_env_64m.bin"

for f in $files; do
	cp -T /tmp/git-cmp/embox-trunk/$f $f
done

git update-index --add --remove -- $files

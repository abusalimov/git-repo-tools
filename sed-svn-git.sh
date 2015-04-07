#!/bin/bash


files="Doxyfile \
	mk/image2.mk \
	mk/image3.mk \
	scripts/config-builder_2_0/mcscan.py \
	scripts/config-builder_2_0/ui/mcscan.py \
	scripts/ConfigBuilder/Parser/mcscan.py"

git checkout-index -q -f -- $files

for f in Doxyfile; do
	[[ -f $f ]] || continue
	sed -i "s:\*/\.svn:.git:g" $f
done

for f in \
		mk/image2.mk \
		mk/image3.mk; do
	[[ -f $f ]] || continue
	sed -i "s/\.svn -type d/.gitkeep -type f/g" $f
	sed -i "s/\.svn/.gitkeep/g" $f
done

for f in \
		scripts/config-builder_2_0/mcscan.py \
		scripts/config-builder_2_0/ui/mcscan.py \
		scripts/ConfigBuilder/Parser/mcscan.py; do
	[[ -f $f ]] || continue
	sed -i "s/\.svn/.git/g" $f
done

for f in $files; do
	[[ -f $f ]] || continue
	git update-index -- $f
	rm -f $f
done

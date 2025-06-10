#!/bin/sh

#
# dof -- place symlink(7)s to dot-files in $HOME directory.
#

base="$HOME"
dof_dir=".dof"

cd "$base/$dof_dir"
dot_files=$(find . -not -path "./.git/*" -type f \
    |sed "s/^\.\///g")

for dot_file in $dot_files; do
	mkdir -p $(dirname "$base/$dot_file")
	ln -s -f "$base/$dof_dir/$dot_file" "$base/$dot_file"
done

#!/bin/sh

#
# grab -- find files containing pattern.
#
# The options are the same as those of grep(1).
#
# By default, it searches for fixed strings only (-F).  Use -E for regexp.
#

grep --exclude-dir=".git" -FRIl "$@"

#!/bin/sh

#
# grab -- find files containing pattern.
#
# The options are the same as those of grep(1).
#

grep --exclude-dir=".git" -RIl "$@"

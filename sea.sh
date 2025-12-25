#!/bin/sh

#
# sea -- search and highlight pattern matches in files.
#
# It's a wrapper for grep(1), thus, it accepts the same options.
#

GREP_COLOR="1;7" grep --exclude-dir=".git" --color=always -RnI "$@"

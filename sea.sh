#!/bin/sh

#
# sea -- search and highlight pattern matches in files.
#
# It's a wrapper for grep(1), thus, it accepts the same options.
#
# By default, it makes grep(1) search for fixed strings only (-F option), so
# if you want to make use of regular expression, you should specify -E option.
#

if [ -t 0 ]; then
	recurs_opt="R"
	linenum_opt="n"
fi
GREP_COLOR="1;7" grep --exclude-dir=".git" --color=always \
    -F${recurs_opt}${linenum_opt}I "$@"

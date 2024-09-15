#!/bin/sh
#find matches. case insensitive by default.
#use --no-ignore case as first param to override it.
GREP_COLOR="1;7" grep -Rin --color=always "$@"

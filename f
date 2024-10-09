#!/bin/sh
#find matches. case sensitive.
#use ~/bin/fj for case insensitive version of it.
GREP_COLOR="1;7" grep --exclude-dir=".git" --color=always -RnI "$@"

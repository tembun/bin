#!/bin/sh
#find matches. case sensitive.
#use ~/bin/fj for case insensitive version of it.

if [ -t 0 ]
then GREP_COLOR="1;7" grep --exclude-dir=".git" --color=always -RnI "$@"
else GREP_COLOR="1;7" grep --exclude-dir=".git" --color=always -nI "$1"
fi

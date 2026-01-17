#!/bin/sh

#
# templ -- make file templates.
#
# The templates should be stored in a format:
# 	"%s.%s", <template name> <extension>
# Though, when invoking the script, <template name> and <extension> should be
# specified in the reverse (slightlyt unnatural) order.
#

TEMPLATES_DIR="usr/local/share/templ"

progname=$(basename "$0" .sh)

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

usage()
{
	local exts=$(get_all_exts)
	local exts_split=$(printf "${exts}" |perl -0pe 's/\n/ | /g')
	local exts_arg="<${exts_split}>"
	local name_arg="<template name>"
	local ext_templates ext_templates_split
	if [ -n "${ext}" ]; then
		ext_templates=$(get_template_basenames "${ext}")
		if [ -n "${ext_templates}" ]; then
			exts_arg="${ext}"
			ext_templates_split=$(printf "${ext_templates}" \
			    |perl -0pe 's/\n/ | /g')
			name_arg="<${ext_templates_split}>"
		fi
	fi
	echo "usage: ${progname} ${exts_arg} ${name_arg}" 1>&2
	exit 2
}

# contains value list
contains()
{
	local val="${1}"
	shift
	echo "$@" |grep -q "^${val}$"
}

check_templates_dir()
{
	[ -d "${TEMPLATES_DIR}" ]
}

get_all_exts()
{
	get_templates |sed 's/.*\.//' |sort -u 2>/dev/null
}

# get_template_names ext?
#	If ext is not set, all templates are returned.
get_templates()
{
	local ext="${1}"
	local all_templates=$(find "${TEMPLATES_DIR}" -type f 2>/dev/null)
	if [ -z "$ext" ]; then
		echo "${all_templates}"
	else
		echo "${all_templates}" |grep "\.${ext}$"
	fi
	
}

# get_template_names ext
get_template_basenames()
{
	get_templates "${ext}" |xargs -L 1 basename |sed 's/\.[^.]*$//'
}

# get_template_path ext name
get_template_path()
{
	echo "${TEMPLATES_DIR}/${2}.${1}"
}

# check_template ext name
check_template()
{
	local path=$(get_template_path "${1}" "${2}")
	[ -f "${path}" ]
}

# print_template ext name
#	The template file shall already be validated.
print_template()
{
	cat "${TEMPLATES_DIR}/${name}.${ext}" 2>/dev/null
}

check_templates_dir || err "${TEMPLATES_DIR} doesn't exist"
[ $# -eq 0 ] && usage
ext="${1}"
all_exts=$(get_all_exts)
contains "${ext}" "${all_exts}" || usage
[ $# -eq 2 ] || usage
name="${2}"
check_template "${ext}" "${name}" || usage
print_template "${ext}" "${name}"

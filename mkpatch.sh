#!/bin/sh

#
# mkpatch -- make and save the source code patch.
#

progname=$(basename "${0}" .sh)
PATCHES_DIR="${HOME}/dev/patches"

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

usage()
{
	cat 1>&2 <<__EOF__
usage: ${progname} -[CFv] [-d directory] patch-name

By default it makes a patch out of the last commit.  In addition, the
full-context patch is also created.  By default, patches are saved under
${PATCHES_DIR}.

Options:
    -C			Make a patch of out the current working tree.
    -F			Don't additionally produce a full-context patch.
    -v			Print patch files as they are created.
    -d directory	Put resulting patches in the specified directory.
__EOF__
	exit 2
}

check_prog()
{
	test -x $(which "${1}" 2>/dev/null)
}

ensure_prog()
{
	check_prog "${1}" || err "You need ${1} to run this script"
}

check_git_repo()
{
	test "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true"
}

ensure_git_repo()
{
	check_git_repo || err "Not inside a git repository"
}

prepare_out_dir()
{
	local dir_arg="${1}"
	local dir="${PATCHES_DIR}"
	# Deduplicate repeated and trim trailing slashes.
	[ -n "${dir_arg}" ] && dir=$(echo "${dir_arg}" \
	    |sed -E -e 's#/+#/#g' -e 's#/+$##')
	mkdir -p "${dir}" || err "Can't mkdir(1) ${dir}"
	setvar out_dir "${dir}"
}

make_patch()
{
	local name="${1}"
	local out_dir="${2}"
	local out_short="${out_dir}/${name}.patch"
	local out_full="${out_short}.full"
	local diff_cmd="show"
	[ "${from_diff}" = "1" ] && diff_cmd="diff"
	ensure_git_repo
	# First stage all the files in order to have newly added (untracked)
	# files in the git-diff(1) output.
	if [ "${from_diff}" = "1" ]; then
		git add -A >/dev/null || err "Can't git-add(1) all the files"
	fi
	git "${diff_cmd}" HEAD --output="${out_short}" || \
		"Can't make the patch and write it to ${out_short}"
	[ "${verbose}" = "1" ] && echo "${out_short}"
	if [ "${need_full}" = "1" ]; then
		git "${diff_cmd}" -U99999 HEAD --output="${out_full}" || \
		    "Can't make the full patch and write it to ${out_full}"
		[ "${verbose}" = "1" ] && echo "${out_full}"
	fi
	if [ "${from_diff}" = "1" ]; then
		git reset HEAD >/dev/null || "Can't git-reset(1) to the HEAD"
	fi
}

handle_opts()
{
	local o
	while getopts 'CFd:v' o; do
		case "${o}" in
		C)	setvar from_diff 1 ;;
		F)	setvar need_full 0 ;;
		d)	setvar out_dir_opt "${OPTARG}" ;;
		v)	setvar verbose 1 ;;
		?)	usage ;;
		esac
	done
}

ensure_prog git
handle_opts ${@}
shift $((OPTIND - 1))
diff_cmd='show'
[ -z "${need_full}" ] && need_full=1
[ -z "${verbose}" ] && verbose=0
[ ${#} -ne 1 ] && usage
patch_name="${1}"
prepare_out_dir "${out_dir_opt}"
make_patch "${patch_name}" "${out_dir}"

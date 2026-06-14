#!/bin/sh

#
# brio -- build the FreeBSD system from source.
#

progname=$(basename -- "${0}" .sh)
SRC_DEFAULT="/usr/src"
MODE_BUILD="build"
TARGET_WORLD="world"
TARGET_KERNEL="kernel"
TARGET_UNIVERSE="universe"
MODE_INSTALL="install"
WORLD_BUILD_MAKE="buildworld"
WORLD_INSTALL_MAKE="installworld"
KERNEL_BUILD_MAKE="buildkernel"
KERNEL_INSTALL_MAKE="installkernel"
DELETE_OLD_MAKE="delete-old delete-old-libs -DBATCH_DELETE_OLD_FILES"
UNIVERSE_BUILD_MAKE="${WORLD_BUILD_MAKE} ${KERNEL_BUILD_MAKE}"
UNIVERSE_INSTALL_MAKE="${WORLD_INSTALL_MAKE} ${KERNEL_INSTALL_MAKE}"
MODE_SYNC="sync"
SYNC_REMOTE_DEFAULT="origin"
MODE_DEFAULT="${MODE_BUILD}"
FILEMON="filemon"
KERN_CONF_VAR="KERNCONF"
KERN_INST_NAME_VAR="INSTKERNNAME"
GIT="git"

usage()
{
	local COMMON_OPTS="[-s source_dir]"
	local WORLD_INSTALL_OPTS="[-DE]"
	local KERN_INSTALL_OPTS="[-n kern_install_name]"
	local KERNEL_NAME_STR="kernel_name"
	cat 1>&2 <<__EOF__
usage: ${progname} ${COMMON_OPTS} ['${MODE_INSTALL}'] '${TARGET_WORLD}' ${WORLD_INSTALL_OPTS}
       ${progname} ${COMMON_OPTS} ['${MODE_INSTALL}'] '${TARGET_KERNEL}' ${KERN_INSTALL_OPTS} ${KERNEL_NAME_STR}
       ${progname} ${COMMON_OPTS} ['${MODE_INSTALL}'] '${TARGET_UNIVERSE}' ${WORLD_INSTALL_OPTS} ${KERN_INSTALL_OPTS} ${KERNEL_NAME_STR}
       ${progname} ${COMMON_OPTS} '${MODE_SYNC}' [-r remote] [branch]
__EOF__
	exit 2
}

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

ensure_dir()
{
	local dir="${1}"
	test -d "${dir}" || err "${dir} is not a directory"
}

ensure_kern_conf()
{
	local kern="${1}"
	local config="${kern_conf_dir}/${kern}"
	test -f "${config}" || err "Kernel config not found: ${config}"
}

require_kern()
{
	local kern="${1}"
	test -n "${kern}" || usage
	ensure_kern_conf "${kern}"
}

check_prog()
{
	local prog="${1}"
	local path=$(which "${prog}" 2>/dev/null)
	test -n "${path}" && test -x "${path}"
}

contains()
{
	local val="${1}"
	shift
	echo "${@}" |grep -q "^${val}$"
}

ensure_kld()
{
	local mod="${1}"
	kldstat -qm "${mod}" || err "${mod}(4) is not loaded into the kernel"
}

git_get_branch()
{
	local path="${1}"
	"${GIT}" -C "${path}" branch --show-current
}

git_get_all_branches()
{
	local path="${1}"
	"${GIT}" -C "${path}" branch |sed "s/^[\* ]*//"
}

git_ensure_clean()
{
	local path="${1}"
	local tree_modified=$("${GIT}" -C "${path}" status --porcelain)
	test -z "${tree_modified}" || err "Your working tree is dirty: ${path}"
}

git_ensure_branch()
{
	local path="${1}"
	local branch="${2}"
	local all_branches=$(git_get_all_branches "${path}")
	contains "${branch}" "${all_branches}" || err "Branch not found: ${branch}"
}

git_pull_branch()
{
	local path="${1}"
	local remote="${2}"
	local branch="${3}"
	"${GIT}" -C "${path}" pull "${remote}" "${branch}" ||
	    err "Cannot pull branch ${branch} from remote ${remote}"
}

check_install_mode()
{
	test "${mode}" = "${MODE_INSTALL}"
}

world_preinstall()
{
	if [ "${no_etcupdate}" != "1" ]; then
		etcupdate -p || err "etcupdate(8) -p exited with error code"
	fi
}

world_postinstall()
{
	if [ "${no_etcupdate}" != "1" ]; then
		etcupdate -B || err "etcupdate(8) -B exited with error code"
	fi
}

preinstall()
{
	if [ "${target}" = "${TARGET_WORLD}" ] || [ "${target}" = "${TARGET_UNIVERSE}" ]; then
		world_preinstall
	fi
}

premake()
{
	if check_install_mode; then
		preinstall
	fi
}

postinstall()
{
	if [ "${target}" = "${TARGET_WORLD}" ] || [ "${target}" = "${TARGET_UNIVERSE}" ]; then
		world_postinstall
	fi
}

postmake()
{
	if check_install_mode; then
		postinstall
	fi
}

handle_opts()
{
	local o
	while getopts "s:" o; do
		case "${o}" in
		s)	src="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

handle_build_install_opts()
{
	local target="${1}"
	local mode="${2}"
	local optstr o
	shift 2
	if [ "${target}" = "${TARGET_WORLD}" ] || [ "${target}" = "${TARGET_UNIVERSE}" ]; then
		case "${mode}" in
		"${MODE_INSTALL}")	optstr="${optstr}DE" ;;
		esac
	fi
	if [ "${target}" = "${TARGET_KERNEL}" ] || [ "${target}" = "${TARGET_UNIVERSE}" ]; then
		case "${mode}" in
		"${MODE_INSTALL}")	optstr="${optstr}n:" ;;
		esac
	fi
	while getopts "${optstr}" o; do
		case "${o}" in
			D)	no_delete_old=1 ;;
			E)	no_etcupdate=1 ;;
			n)	kern_inst_name="${OPTARG}" ;;
			?)	usage ;;
		esac
	done
}

do_make()
{
	local src="${1}"
	local make_cmd="${2}"
	local make_vars="${3}"
	make -C "${src}" \
		-j $(sysctl -n hw.ncpu) \
		${make_cmd} ${make_vars}
}

handle_build_install_modes()
{
	local target="${1}"
	local kern world_install_make kern world_install_make_extra universe_install_make
	shift
	handle_build_install_opts "${target}" "${mode}" ${@}
	shift $((OPTIND - 1))
	test "${no_delete_old}" != "1" && world_install_make_extra="${DELETE_OLD_MAKE}"
	world_install_make="${WORLD_INSTALL_MAKE} ${world_install_make_extra}"
	universe_install_make="${UNIVERSE_INSTALL_MAKE} ${world_install_make_extra}"

	case "${target}" in
	"${TARGET_WORLD}")
		test ${#} -eq 0 || usage
		if check_install_mode; then
			make_cmd="${world_install_make}"
		else
			make_cmd="${WORLD_BUILD_MAKE}"
		fi
		;;
	"${TARGET_KERNEL}")
		kern="${1}"
		require_kern "${kern}"
		if check_install_mode; then
			make_cmd="${KERNEL_INSTALL_MAKE}"
		else
			make_cmd="${KERNEL_BUILD_MAKE}"
		fi
		;;
	"${TARGET_UNIVERSE}")
		kern="${1}"
		require_kern "${kern}"
		if check_install_mode; then
			make_cmd="${universe_install_make}"
		else
			make_cmd="${UNIVERSE_BUILD_MAKE}"
		fi
		;;
	*)	usage ;;
	esac

	case "${target}" in
	"${TARGET_KERNEL}"|"${TARGET_UNIVERSE}")
		make_vars="${KERN_CONF_VAR}=${kern}"
		if check_install_mode; then
			test -n "${kern_inst_name}" &&
			    make_vars="${make_vars} ${KERN_INST_NAME_VAR}=${kern_inst_name}"
		fi
		;;
	*)	test -n "${kern_inst_name}" && usage ;;
	esac

	ensure_dir "${src}"
	ensure_kld "${FILEMON}"

	premake
	do_make "${src}" "${make_cmd}" "${make_vars}"
	postmake
}

handle_opts_sync()
{
	local o
	while getopts "r:" o; do
		case "${o}" in
		r)	sync_remote="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

sync_current_branch()
{
	local branch="${1}"
	git_pull_branch "${src}" "${sync_remote}" "${branch}"
}

sync_other_branch()
{
	local branch="${1}"
	"${GIT}" -C "${src}" checkout "${branch}" || err "Cannot checkout branch: ${branch}"
	git_pull_branch "${src}" "${sync_remote}" "${branch}"
	"${GIT}" -C "${src}" pull "${sync_remote}" "${branch}" ||
	    err "Cannot pull branch ${branch} from remote ${sync_remote}"
	"${GIT}" -C "${src}" checkout - || err "Cannot checkout to previous branch"
	"${GIT}" -C "${src}" rebase "${branch}" ||
	    err "Cannot rebase ${current_branch} on top of ${branch}"
}

handle_sync_mode()
{
	handle_opts_sync "${@}"
	shift $((OPTIND - 1))
	: ${sync_remote:="${SYNC_REMOTE_DEFAULT}"}
	local branch current_branch
	check_prog "${GIT}" || err "You need "${GIT}" for ${MODE_SYNC} mode"
	current_branch=$(git_get_branch "${src}")
	branch="${1:-"${current_branch}"}"
	git_ensure_branch "${src}" "${branch}"
	git_ensure_clean "${src}"
	if [ "${current_branch}" = "${branch}" ]; then
		sync_current_branch "${branch}"
	else
		sync_other_branch "${branch}"
	fi
}

handle_opts "${@}"
shift $((OPTIND - 1))
: "${src:="${SRC_DEFAULT}"}"
arch=$(uname -p)
kern_conf_dir="${src}/sys/${arch}/conf"
test ${#} -gt 0 || usage
case "${1}" in
"${MODE_INSTALL}"|"${MODE_SYNC}")
	mode="${1}"
	shift
	;;
*)	mode="${MODE_DEFAULT}" ;;
esac
case "${mode}" in
"${MODE_BUILD}"|"${MODE_INSTALL}")	handle_build_install_modes "${@}" ;;
"${MODE_SYNC}")				handle_sync_mode "${@}" ;;
esac

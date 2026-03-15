#!/bin/sh

#
# cgitrepo -- create a remote git(1) repository with cgit(1).
#

progname=$(basename "${0}")
CONFIG_PATH="${HOME}/.cgitreporc"
ARCHIVE_BASENAME="cgitrepo.txz"
GIT="git"
CGITREPOS_BASENAME="_cgitrepos"
: "${TMPDIR:="/tmp"}"

usage()
{
	echo "${progname}: repo [name]"
	exit 2
}

prompt()
{
	local answ status
	printf "${@}: " 1>&2
	read answ
	status=${?}
	# EOF or trapped signal
	if [ ${status} -eq 1 ] || [ ${status} -gt 128 ]; then
		status=1
	else
		status=0
	fi
	echo "${answ}"
	return ${status}
}

_warn()
{
	echo "${@}" 1>&2
	return 1
}

err()
{
	_warn "${progname}: ${@}"
	exit 1
}

cleanup()
{
	rm -rf "${Tmp_dir}"
}
trap cleanup INT TERM EXIT

ensure_prog()
{
	local prog="${1}"
	local path=$(which "${prog}" 2>/dev/null)
	test -n "${path}" && test -x "${path}" || err "You need ${prog} to run this"
}

make_tmp_dir()
{
	Tmp_dir=$(mktemp -d -p "${TMPDIR}")
	Git_tmp_dir="${Tmp_dir}/${REMOTE_REPO_DEST}"
	mkdir -p "${Git_tmp_dir}"
	test ${#} -ne 0 && err "Can't mktemp(1) at ${TMPDIR}"
	Cgitrepos="${Tmp_dir}/${CGITREPOS_BASENAME}"
}

apply_config()
{
	test -f "${CONFIG_PATH}" || err "Can't find config file: ${CONFIG_PATH}"
	. "${CONFIG_PATH}"
	test -n "${REMOTE_HOST}" || err "REMOTE_HOST is not set in config: ${CONFIG_PATH}"
	test -n "${REMOTE_USER}" || err "REMOTE_USER is not set in config: ${CONFIG_PATH}"
	test -n "${REMOTE_REPO_DEST}" || err "REMOTE_REPO_DEST is not set in config: ${CONFIG_PATH}"
	test -n "${REMOTE_TRANSFER_DEST}" || err "REMOTE_TRANSFER_DEST is not set in config: ${CONFIG_PATH}"
	test -n "${REMOTE_CGITREPOS}" || err "REMOTE_CGITREPOS is not set in config: ${CONFIG_PATH}"
}

clone()
{
	local repo="${1}"
	local name="${2}"
	local dest="${Git_tmp_dir}/${name}.git"
	"${GIT}" clone --bare "${repo}" "${dest}" && echo "${dest}"
}

archive()
{
	local src="${1}"
	local dest="${src}/${2}"
	tar -C "${src}" --exclude="./$(basename "${dest}")" \
	    -cJf "${dest}" "." && echo "${dest}"
}

check_remote_repo()
{
	local repo_name="${1}"
	ssh -T "${REMOTE_USER}@${REMOTE_HOST}" >/dev/null <<__EOF__
test -d "${REMOTE_REPO_DEST}/${repo_name}.git" ||
    grep -q "repo\.url=${repo_name}$" "${REMOTE_CGITREPOS}"
__EOF__
}

make_cgitrepos()
{
	local repo_name repo_desc
	while true; do
		repo_name=$(prompt "Repo name")
		test $? -ne 0 && exit 1
		if test -z "${repo_name}"; then
			_warn "Repo name is required"
			continue
		elif check_remote_repo "${repo_name}"; then
			_warn "${repo_name} is already created on ${REMOTE_HOST}"
			continue
		fi
		break
	done
	repo_desc=$(prompt "Repo description")
	test $? -ne 0 && exit 1

	cat >"${Cgitrepos}" <<__EOF__

repo.url=${repo_name}
repo.path=/home/${REMOTE_USER}/${REMOTE_REPO_DEST}/${repo_name}.git
repo.clone-url=${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_REPO_DEST}/${repo_name}
repo.desc=${repo_desc}
__EOF__
}

transfer()
{
	local src="${1}"
	local user="${2}"
	local host="${3}"
	local path="${4}"
	scp "${src}" "${user}@${host}:${path}" >/dev/null
}

extract_remote_archive()
{
	local user="${1}"
	local host="${2}"
	local archive="${3}"
	ssh -T "${user}@${host}" >/dev/null <<__EOF__
tar xJf "${archive}" || { rm -f "${archive}"; exit 1; }
cat "${CGITREPOS_BASENAME}" >>"${REMOTE_CGITREPOS}"
rm -f "${CGITREPOS_BASENAME}" "${archive}"
__EOF__
}

ensure_prog "${GIT}"
test ${#} -eq 0 && usage
repo="${1}"
repo_name="${2:-$(basename "${repo}")}"
apply_config
make_tmp_dir
bare_repo=$(clone "${repo}" "${repo_name}")
test -z "${bare_repo}" && err "Can't clone repository: ${repo}"
make_cgitrepos || err "Can't make cgitrepos file at: ${Cgitrepos}"
repo_clone_url=$(sed -n 's/repo\.clone-url=//p' "${Cgitrepos}")
repo_archive=$(archive "${Tmp_dir}" "${ARCHIVE_BASENAME}")
test -z "${repo_archive}" && err "Can't archive bare repository: ${bare_repo}"
transfer "${repo_archive}" "${REMOTE_USER}" "${REMOTE_HOST}" "${REMOTE_TRANSFER_DEST}" ||
    err "Can't transfer ${repo_archive} to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TRANFER_DEST}"
remote_archive="$(basename ${repo_archive})"
extract_remote_archive "${REMOTE_USER}" "${REMOTE_HOST}" "${remote_archive}" ||
    err "Can't extract archive at: ${REMOTE_USER}@${REMOTE_HOST}:${remote_archive}"
echo "${repo_clone_url}"

#!/bin/bash

# Continuous Integration Library for RI2
# Author: Renato Silva <br.renatosilva@gmail.com>
# Author: Qian Hong <fracting@gmail.com>

# Enable colors
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
cyan=$(tput setaf 6)

# Basic status function
_status() {
    local type="${1}"
    local status="${package:+${package}: }${2}"
    local items=("${@:3}")
    case "${type}" in
        failure) local -n nameref_color='red';   title='[RI2 CI] FAILURE:' ;;
        success) local -n nameref_color='green'; title='[RI2 CI] SUCCESS:' ;;
        message) local -n nameref_color='cyan';  title='[RI2 CI]'
    esac
    printf "\n${nameref_color}${title}${normal} ${status}\n\n"
    printf "${items:+\t%s\n}" "${items:+${items[@]}}"
}

# Convert lines to array
_as_list() {
    local -n nameref_list="${1}"
    local filter="${2}"
    local strip="${3}"
    local lines="${4}"
    local result=1
    nameref_list=()
    while IFS= read -r line; do
        test -z "${line}" && continue
        result=0
        [[ "${line}" = ${filter} ]] && nameref_list+=("${line/${strip}/}")
    done <<< "${lines}"
    return "${result}"
}

# Changes since master or from head
_list_changes() {
    local list_name="${1}"
    local filter="${2}"
    local strip="${3}"
    local git_options=("${@:4}")
    _as_list "${list_name}" "${filter}" "${strip}" "$(git log "${git_options[@]}" upstream/master.. | sort -u)" ||
    _as_list "${list_name}" "${filter}" "${strip}" "$(git log "${git_options[@]}" HEAD^.. | sort -u)"
}

# Get package information
_package_info() {
    local package="${1}"
    local properties=("${@:2}")
    for property in "${properties[@]}"; do
        local -n nameref_property="${property}"
        nameref_property=($(
            MINGW_PACKAGE_PREFIX='mingw-w64' source "${package}/PKGBUILD"
            declare -n nameref_property="${property}"
            echo "${nameref_property[@]}"))
    done
}

# Package provides another
_package_provides() {
    local package="${1}"
    local another="${2}"
    local pkgname provides
    _package_info "${package}" pkgname provides
    for pkg_name in "${pkgname[@]}";  do [[ "${pkg_name}" = "${another}" ]] && return 0; done
    for provided in "${provides[@]}"; do [[ "${provided}" = "${another}" ]] && return 0; done
    return 1
}

# Add package to build after required dependencies
_build_add() {
    local package="${1}"
    local depends makedepends
    for sorted_package in "${sorted_packages[@]}"; do
        [[ "${sorted_package}" = "${package}" ]] && return 0
    done
    _package_info "${package}" depends makedepends
    for dependency in "${depends[@]}" "${makedepends[@]}"; do
        for unsorted_package in "${packages[@]}"; do
            [[ "${package}" = "${unsorted_package}" ]] && continue
            _package_provides "${unsorted_package}" "${dependency}" && _build_add "${unsorted_package}"
        done
    done
    sorted_packages+=("${package}")
}

# Download previous artifact
_download_previous() {
    local filenames=("${@}")
    [[ "${DEPLOY_PROVIDER}" = bintray ]] || return 1
    for filename in "${filenames[@]}"; do
        if ! wget --no-verbose "https://dl.bintray.com/${BINTRAY_ACCOUNT}/${BINTRAY_REPOSITORY}/${filename}"; then
            rm -f "${filenames[@]}"
            return 1
        fi
    done
    return 0
}

# Git configuration
git_config() {
    local name="${1}"
    local value="${2}"
    test -n "$(git config ${name})" && return 0
    git config --global "${name}" "${value}" && return 0
    failure 'Could not configure Git for makepkg'
}

# Run command with status
execute(){
    local status="${1}"
    local command="${2}"
    local arguments=("${@:3}")
    cd "${package:-.}"
    message "${status}"
    if [[ "${command}" != *:* ]]
        then ${command} ${arguments[@]}
        else ${command%%:*} | ${command#*:} ${arguments[@]}
    fi || failure "${status} failed"
    cd - > /dev/null
}

# Update system
update_system() {
    repman add ci.msys 'https://dl.bintray.com/alexpux/msys2' || return 1
    pacman --noconfirm --sync --refresh --refresh --sysupgrade --sysupgrade || return 1
    test -n "${DISABLE_QUALITY_CHECK}" && return 0 # TODO: remove this option when not anymore needed
    pacman --noconfirm --needed --sync ci.msys/pactoys
}

# Sort packages by dependency
define_build_order() {
    local sorted_packages=()
    for unsorted_package in "${packages[@]}"; do
        _build_add "${unsorted_package}"
    done
    packages=("${sorted_packages[@]}")
}

# Associate artifacts with this build
create_build_references() {
    local repository_name="${1}"
    local references="${repository_name}.builds"
    _download_previous "${references}" || failure "Download ${references} failed"
    for file in *; do
        sed -i "/^${file}.*/d" "${references}"
        printf '%-80s%s\n' "${file}" "${BUILD_URL}" >> "${references}"
    done
    sort "${references}" | tee "${references}.sorted" | sed -r 's/(\S+)\s.*\/([^/]+)/\2\t\1/'
    mv "${references}.sorted" "${references}"
}

# Add packages to repository
create_pacman_repository() {
    local name="${1}"
    _download_previous "${name}".{db,files}{,.tar.xz}{,.sig}
    repo-add --sign --verify "${name}.db.tar.xz" *.pkg.tar.zst
}

_drop_bintray_files() {
    local filenames=("${@}")
    [[ "${DEPLOY_PROVIDER}" = bintray ]] || return 1
    for filename in "${filenames[@]}"; do
        echo -n "bintray delete ${filename} "
        curl -X DELETE "-u${BINTRAY_ACCOUNT}:${BINTRAY_API_KEY}" "https://api.bintray.com/content/${BINTRAY_ACCOUNT}/${BINTRAY_REPOSITORY}/${filename}"
        echo
    done
}

drop_old_bintray_versions() {
    local package="${1}"
    local sdate=$(date +%Y-%m-%d)
    for i in {1..30}; do
        local rdate=$(date +%Y%m%d -d "${sdate} - $i day")

        if [[ "${package}" = "mingw-w64-ruby-head" ]]; then
          # mingw-w64-i686-ruby-head-r20170628-1-any.pkg.tar.xz
          _drop_bintray_files mingw-w64-{i686,x86_64}-ruby-head-r${rdate}-1-any.pkg.tar.{xz,zst}{,.sig}
          # mingw-w64-ruby-head-r20170712-1.src.tar.gz
          _drop_bintray_files mingw-w64-ruby-head-r${rdate}-1.src.tar.gz{,.sig}
        fi
    done
}

# Deployment is enabled
deploy_enabled() {
    test -n "${BUILD_URL}" || return 1
    [[ "${DEPLOY_PROVIDER}" = bintray ]] || return 1
    [[ -n "${GPGPASSWD}" ]]
}

# Added commits
list_commits()  {
    _list_changes commits '*' '#*::' --pretty=format:'%ai::[%h] %s'
}

# Changed recipes
list_packages() {
    local _packages
    _list_changes _packages '*/PKGBUILD' '%/PKGBUILD' --pretty=format: --name-only || return 1
    for _package in "${_packages[@]}"; do
        local find_case_sensitive="$(find -name "${_package}" -type d -print -quit)"
        test -n "${find_case_sensitive}" && packages+=("${_package}")
    done
    return 0
}

# Recipe quality
check_recipe_quality() {
    # TODO: remove this option when not anymore needed
    if test -n "${DISABLE_QUALITY_CHECK}"; then
        echo 'This feature is disabled.'
        return 0
    fi
    saneman --format='\t%l:%c %p:%c %m' --verbose --no-terminal "${packages[@]}"
}

# Add ci.ri2 repository
add_ci_ri2_repo() {
    # Trust public signature key
    gpg --export BE8BF1C5 | pacman-key --add -
    pacman-key --lsign-key BE8BF1C5

    if grep -Fxq "[ci.ri2]" /etc/pacman.conf
    then
        echo "[ci.ri2] already in /etc/pacman.conf"
    else
        echo "add [ci.ri2] to /etc/pacman.conf"
        cat >>/etc/pacman.conf <<-EOT

# Added by appveyor build script
[ci.ri2]
Server = http://dl.bintray.com/larskanis/rubyinstaller2-packages
EOT
    fi

    # Download [ci.ri2] package list
    pacman --noconfirm --sync --refresh
    return 0
}

# Status functions
failure() { local status="${1}"; local items=("${@:2}"); _status failure "${status}." "${items[@]}"; exit 1; }
success() { local status="${1}"; local items=("${@:2}"); _status success "${status}." "${items[@]}"; exit 0; }
message() { local status="${1}"; local items=("${@:2}"); _status message "${status}"  "${items[@]}"; }

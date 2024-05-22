#!/bin/bash

# AppVeyor and Drone Continuous Integration for MSYS2
# Author: Renato Silva <br.renatosilva@gmail.com>
# Author: Qian Hong <fracting@gmail.com>

# Configure
cd "$(dirname "$0")"
source 'ci-library.sh'
# deploy_enabled && mkdir artifacts
mkdir artifacts
git_config user.email 'jayesh.s@iitgn.ac.in'
git_config user.name  'Vishal1309'
git remote add upstream 'https://github.com/Vishal1309/rubyinstaller2-packages'
git fetch --quiet upstream

# Decrypt and import private sigature key
message 'pls help'
# message "${GPGPASSWD}"
# deploy_enabled && (gpg --batch --passphrase "${GPGPASSWD}" --decrypt appveyor-key.asc.asc | gpg --import)

# Detect
if [ -z "${APPVEYOR_SCHEDULED_BUILD}" ]
then
    list_commits  || failure 'Could not detect added commits'
    list_packages || failure 'Could not detect changed files'
    message 'Processing changes' "${commits[@]}"
    test -z "${packages}" && success 'No changes in package recipes'
else
    # Scheduled build? Build the daily snapshot ruby version.
    packages=( mingw-w64-ruby-head )
fi
define_build_order || failure 'Could not determine build order'
message 'Building packages' "${packages[@]}"

execute 'Add [test_tag] respository to pacman.conf' add_ci_ri2_repo

# Build
execute 'Approving recipe quality' check_recipe_quality
for package in "${packages[@]}"; do
    arch_matches=$( sh -c "source ${package}/PKGBUILD && if [[ \" \${mingw_arch[@]} \" =~ \" ${MINGW_ARCH} \" ]]; then echo yes; fi " )
    if [[ ${arch_matches} == "yes" ]]; then
        execute "Building binary for arch ${MINGW_ARCH}" makepkg-mingw --noconfirm --skippgpcheck --nocheck --syncdeps --rmdeps --cleanbuild --sign
    #     execute 'Installing' yes:pacman --upgrade *.pkg.tar.zst
    #     execute 'Uninstalling' yes:pacman --remove --recursive --cascade --noconfirm "${package/mingw-w64/mingw-w64-i686}" "${package/mingw-w64/mingw-w64-x86_64}" "${package/mingw-w64/mingw-w64-ucrt-x86_64}"
        # deploy_enabled && mv "${package}"/*.pkg.tar.zst "${package}"/*.pkg.tar.zst.sig artifacts
        mv "${package}"/*.pkg.tar.zst "${package}"/*.pkg.tar.zst.sig artifacts
    #     deploy_enabled && drop_old_bintray_versions "${package}"
    else
        execute "skip unsupported package arch ${MINGW_ARCH}"
    fi
    unset package
done

success 'All packages built successfully'

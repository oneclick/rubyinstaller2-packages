#!/bin/bash

# AppVeyor and Drone Continuous Integration for MSYS2
# Author: Renato Silva <br.renatosilva@gmail.com>
# Author: Qian Hong <fracting@gmail.com>

# Configure
cd "$(dirname "$0")"
source 'ci-library.sh'
deploy_enabled && mkdir artifacts
git_config user.email 'ci@rubyinstaller.org'
git_config user.name  'RubyInstaller2 Continuous Integration'
git remote add upstream 'https://github.com/oneclick/rubyinstaller2-packages'
git fetch --quiet upstream

# Detect
if [ -z $APPVEYOR_SCHEDULED_BUILD ]
then
    list_commits  || failure 'Could not detect added commits'
    list_packages || failure 'Could not detect changed files'
    message 'Processing changes' "${commits[@]}"
    test -z "${packages}" && success 'No changes in package recipes'
else
    # Scheduled build? Build the daily snapshot ruby version.
    packages=( mingw-w64-ruby-trunk )
fi
define_build_order || failure 'Could not determine build order'
message 'Building packages' "${packages[@]}"

execute 'Updating system' update_system

# Decrypt and import private sigature key
deploy_enabled && (gpg --passphrase $GPGPASSWD --decrypt appveyor-key.asc.asc | gpg --import)
execute 'Add [ci.ri2] respository' add_ci_ri2_repo

# Build
execute 'Approving recipe quality' check_recipe_quality
for package in "${packages[@]}"; do
    execute 'Building binary' makepkg-mingw --noconfirm --skippgpcheck --nocheck --syncdeps --rmdeps --cleanbuild --sign
    execute 'Building source' makepkg --noconfirm --skippgpcheck --allsource --config '/etc/makepkg_mingw64.conf' --sign
    execute 'Installing' yes:pacman --upgrade *.pkg.tar.xz
    execute 'Uninstalling' yes:pacman --remove --recursive --noconfirm "${package/mingw-w64/mingw-w64-i686}" "${package/mingw-w64/mingw-w64-x86_64}"
    deploy_enabled && mv "${package}"/*.pkg.tar.xz* artifacts
    deploy_enabled && mv "${package}"/*.src.tar.gz* artifacts
    deploy_enabled && drop_old_bintray_versions "${package}"
    unset package
done

# Deploy
deploy_enabled && cd artifacts || success 'All packages built successfully'
execute 'Generating pacman repository' create_pacman_repository "${PACMAN_REPOSITORY_NAME:-ci-build}"
execute 'Generating build references'  create_build_references  "${PACMAN_REPOSITORY_NAME:-ci-build}"
execute 'SHA-256 checksums' sha256sum *
success 'All artifacts built successfully'

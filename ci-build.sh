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

# Decrypt and import private sigature key
gpg --passphrase $gpgpasswd --decrypt appveyor-key.asc.asc | gpg --import
# Download and trust public signatur key
pacman-key --recv-keys BE8BF1C5
pacman-key --lsign-key BE8BF1C5

# Detect
if [ -z $APPVEYOR_SCHEDULED_BUILD ]
then
    list_commits  || failure 'Could not detect added commits'
    list_packages || failure 'Could not detect changed files'
    message 'Processing changes' "${commits[@]}"
    test -z "${packages}" && success 'No changes in package recipes'
else
    # Scheduled build? Build the daily snapshot ruby version.
    packages=( mingw-w64-ruby25 )
fi
define_build_order || failure 'Could not determine build order'

# Build
message 'Building packages' "${packages[@]}"
execute 'Updating system' update_system
execute 'Approving recipe quality' check_recipe_quality
for package in "${packages[@]}"; do
    execute 'Building binary' makepkg-mingw --noconfirm --noprogressbar --skippgpcheck --nocheck --syncdeps --rmdeps --cleanbuild --sign
    execute 'Building source' makepkg --noconfirm --noprogressbar --skippgpcheck --allsource --config '/etc/makepkg_mingw64.conf' --sign
    execute 'Installing' yes:pacman --noprogressbar --upgrade *.pkg.tar.xz
    deploy_enabled && mv "${package}"/*.pkg.tar.xz* artifacts
    deploy_enabled && mv "${package}"/*.src.tar.gz* artifacts
    unset package
done

# Deploy
deploy_enabled && cd artifacts || success 'All packages built successfully'
execute 'Generating pacman repository' create_pacman_repository "${PACMAN_REPOSITORY_NAME:-ci-build}"
execute 'Generating build references'  create_build_references  "${PACMAN_REPOSITORY_NAME:-ci-build}"
execute 'SHA-256 checksums' sha256sum *
success 'All artifacts built successfully'

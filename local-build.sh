#!/bin/bash
set -ex

export DEPLOY_REPO_NAME=oneclick/rubyinstaller2-packages
export DEPLOY_TAG=ci.ri2

source ./ci-library.sh

rm -rf artifacts
mkdir -p artifacts
cd mingw-w64-ruby-head
rm -f snapshot-master.tar.xz
rm -f *.pkg.tar.zst *.pkg.tar.zst.sig
makepkg-mingw --noconfirm --nocheck --syncdeps --rmdeps --cleanbuild --sign -f
cp *.pkg.tar.zst *.pkg.tar.zst.sig ../artifacts/
cd ../artifacts/
rm -f ci.ri2.*
create_pacman_repository 'ci.ri2'
cd ..
rake upload -- artifacts/*.pkg.tar.zst artifacts/*.pkg.tar.zst.sig artifacts/*.db.tar.zst artifacts/*.db.tar.zst.sig artifacts/*.db artifacts/*.db.sig artifacts/*.files.tar.zst artifacts/*.files.tar.zst.sig artifacts/*.files artifacts/*.files.sig

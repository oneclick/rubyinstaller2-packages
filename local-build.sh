#!/bin/bash
set -ex

export DEPLOY_REPO_NAME=oneclick/rubyinstaller2-packages
export DEPLOY_TAG=ci.ri2
if [[ ${DEPLOY_TOKEN:0:2} != "gh" ]] ; then echo "DEPLOY_TOKEN has no valid access token"; exit 1; fi

source ../ci-library.sh

rm -f snapshot-master.tar.xz
rm -f *.pkg.tar.zst *.pkg.tar.zst.sig
makepkg-mingw --noconfirm --nocheck --syncdeps --rmdeps --cleanbuild --sign -f
rm -rf artifacts
mkdir -p artifacts
cp *.pkg.tar.zst *.pkg.tar.zst.sig artifacts/
cd artifacts/
rm -f ci.ri2.*

export DEPLOY_LOCK=$(ruby -e 'puts rand')
rake upload:lock
create_pacman_repository 'ci.ri2'
cd ../..
rake upload -- $OLDPWD/*.pkg.tar.zst $OLDPWD/*.pkg.tar.zst.sig $OLDPWD/*.db.tar.zst $OLDPWD/*.db.tar.zst.sig $OLDPWD/*.db $OLDPWD/*.db.sig $OLDPWD/*.files.tar.zst $OLDPWD/*.files.tar.zst.sig $OLDPWD/*.files $OLDPWD/*.files.sig
rake upload:unlock

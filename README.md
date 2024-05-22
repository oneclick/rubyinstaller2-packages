# MSYS2-MINGW packages for RubyInstaller2

[![CI build status](https://github.com/Vishal1309/rubyinstaller2-packages/actions/workflows/ci.yml/badge.svg)](https://github.com/Vishal1309/rubyinstaller2-packages/actions/workflows/ci.yml)

This repository contains package scripts for MinGW-w64 targets to build under MSYS2.
The main intension of this repository is to provide binary ruby packages for [RubyInstaller2](https://github.com/Vishal1309/rubyinstaller2) in several versions.

Packages are built on Github Actions when the corresponding directory has changed in the last commit.
They are subsequently signed and uploaded to this [github release](https://github.com/Vishal1309/rubyinstaller2-packages/releases/tag/test_tag).
In addition the latest ruby-head snapshot is build and uploaded on a daily base.
The github release also contains pacman database files and is usable as a pacman repository.

## Install packages

Packages from this repository can be downloaded here: https://github.com/Vishal1309/rubyinstaller2-packages/releases/tag/test_tag

It is also possible to add the RubyInstaller repository as a pacman repository in your MSYS2 installation.
Execute this within a MSYS2 shell to download and trust the public signatur key and to add the new package source:
```sh
pacman --noconfirm --sync --needed pactoys
pacman-key --recv-keys BE8BF1C5
pacman-key --lsign-key BE8BF1C5
repman add test_tag "https://github.com/Vishal1309/rubyinstaller2-packages/releases/download/test_tag"
```

You can then install or update MSYS2-MINGW ruby like so:
```sh
pacman -Sy mingw-w64-ucrt-x86_64-ruby31
```

## Build packages for yourself
Second option is to clone git repository to your machine and build it for yourself.
Assuming you have a properly installed MSYS2 environment and build tools, you can build any package using the following command.
Replace `${package-name}` with the package name in question:
```sh
   cd mingw-w64-${package-name}
   MINGW_ARCH=ucrt64 makepkg-mingw -sLf
```

Or in a CMD shell:
```sh
   cd mingw-w64-${package-name}
   ridk enable
   set MINGW_ARCH=ucrt64
   sh -c "makepkg-mingw -sLf"
```

After that you can install the freshly built package(s) with the following command:
```sh
   pacman -U mingw-w64-ucrt-x86_64-${package-name}*.pkg.tar.zst
```

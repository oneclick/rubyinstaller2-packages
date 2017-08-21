# MSYS2-MINGW packages for RubyInstaller2

[![Build status](https://ci.appveyor.com/api/projects/status/a27uf6omaj2okbyc/branch/master?svg=true)](https://ci.appveyor.com/project/larskanis/rubyinstaller2-packages/branch/master)

This repository contains package scripts for MinGW-w64 targets to build under MSYS2.
The main intension of this repository is to provide binary ruby packages for [RubyInstaller2](https://github.com/oneclick/rubyinstaller2) in several versions.

Packages are built on Appveyor when the corresponding directory has changed in the last commit.
They are subsequently signed and uploaded to a bintray repository.
In addition the latest ruby-2.5 snapshot is build and uploaded on a daily base.

## Install packages

Packages from this repository can be downloaded here: https://dl.bintray.com/larskanis/rubyinstaller2-packages/

It is also possible to add the RubyInstaller repository as a pacman repository in your MSYS2 installation.
Execute this within a MSYS2 shell to download and trust the public signatur key and to add the new package source:
```sh
pacman-key --recv-keys BE8BF1C5
pacman-key --lsign-key BE8BF1C5
repman add ci.ri2 "http://dl.bintray.com/larskanis/rubyinstaller2-packages"
```

You can then install or update MSYS2-MINGW ruby like so:
```sh
pacman -Sy mingw-w64-x86_64-ruby24
```

## Build packages for yourself
Second option is to clone git repository to your machine and build it for yourself.
Assuming you have a properly installed MSYS2 environment and build tools, you can build any package using the following command:
```sh
   cd ${package-name}
   MINGW_INSTALLS=mingw64 makepkg-mingw -sLf
```
After that you can install the freshly built package(s) with the following command:
```sh
   pacman -U ${package-name}*.pkg.tar.xz
```

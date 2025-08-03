# My configs for T2SDE Linux

Without any warranty!

Please see:
* official homepage of T2SDE Linux: https://t2sde.org/
* my wiki: https://github.com/hpaluch/hpaluch.github.io/wiki/T2SDE

# My first ISO cross-build - "CLI" template

> Why cross-build? Because Host build (stage 9) heavily depends on current
> state of system and often fails for various reasons.
>
> So I have found that cross-build is significantly more stable and reproducible
> than Host build.

> [!WARNING]
> I have to remove `ca-certificates`, because even those now depends on Rust.
> It means that target system will not trust standard certificates, with
> good exception of `curl(1)` that has its own copy of trusted CA in
> `/etc/curl/cacert.pem`.

I created my own template called "CLI" based on "base" in "generic" target.
However I removed all bloat that takes too long to build (`llvm`, `clang`,
`cargo`, `rustc`) and also non x86 stuff.

- you can find original `base` profile under `/usr/src/t2-src/target/generic/pkgsel/20-base.in`
- my CLI profile is under `target/generic/pkgsel/15-cli.in` (has to be copied
  under `/usr/src/t2-src/` later - see text below).

I installed latest T2 version 25.4 from:
`t2-25.4-x86-64-base-wayland-glibc-gcc-nocona.iso`. Then did preparation:

Here are details of cross-build:

```shell
$ cd /usr/src/t2-src/
$ t2 up
$ svn info | grep '^Last Change'

Last Changed Author: rene

ast Changed Rev: 79772
Last Changed Date: 2025-07-18 19:13:15 +0200 (Fri, 18 Jul 2025)

# I need git and mc :-)

$ t2 install -optional-deps=no git mc btop

# These additional tools are required on host system:
# - scons required by serf which is http(s) library for SVN client
# - mtools required for image creation script
# - scdoc still required by kmod under some circumstances

$ t2 install perl perl-xml-parser python python-installer setuptools \
     pip jinja2 ninja meson libtool libxml autoconf scons mtools scdoc
```

Now copy our new Template "cli" (original posted on my branch and project):

- original: https://github.com/hpaluch/t2sde/blob/br-cli-template/target/generic/pkgsel/15-cli.in:
- latest: https://github.com/hpaluch/t2sde-files/blob/master/target/generic/pkgsel/15-cli.in

```shell
cd /usr/src/t2-src
x=target/generic/pkgsel/15-cli.in
curl -fLo $x https://github.com/hpaluch/t2sde-files/raw/refs/heads/master/$x
```

Run `t2 config -cfg crosscli` and change:

```shell
SDECFG_PKGSEL_TMPL='cli'
SDECFG_X8664_OPT='nocona'
SDECFG_CROSSBUILD='1'
SDECFG_CONTINUE_ON_ERROR_AFTER='9
# update for: r77109, 12 May 2025
# required to avoid 1-gcc build errors:
# config: GCC Options -> UNCHECK "Enable GNAT"
SDECFG_PKG_GCC_GNAT='0'
```

Build image with:

```shell
t2 build-target -cfg crosscli
```

Total 210 packages to be build.

I got new error
- at `0-python/setuptools`:
  ```
  /usr/src/t2-src/build/crosscli-25-svn-generic-x86-64-nocona-cross-linux/TOOLCHAIN/cross/bin/python: No module named installer
  ```
- to fix it - apply my patch from: [patches/python-installer-0-fix.diff](patches/python-installer-0-fix.diff)
- and run:
  ```shell
  t2 build-target -cfg crosscli 0-python-installer
  # resume 0 stage build
  t2 build-target -cfg crosscli
  ```

Next error:
- on `2-python/python`:
  ```
  /Modules/_gdbmmodule.c:12:10: fatal error: gdbm.h: No such file or directory
  ```
- looks like there is wrong build order (3rd column)
  ```shell
  $ awk '$5 == "python" || $5 == "gdbm" { print $0 }' config/crosscli/packages
  X 0-2------- 102.300 python python 3.13.5 / base/development CROSS NO-PIE NO-SSP NO-LTO.mips NO-LTO.mips64 NO-LTO.clang 0
  X --2------- 104.800 database gdbm 1.25 / base/library CROSS 0
  ```
- note: I have to use `awk` for package search, because there also exists group "python" rendering `grep -w python` command useless.
  Awk can easily target package column (No. 5).
- trying:
  ```shell
  t2 build-target -cfg crosscli 2-gdbm
  # resume build
  t2 build-target -cfg crosscli
  ```

Hmm, next error:
- again on `2-python/python`:
  ```
  ./Modules/readline.c:43:12: fatal error: readline/readline.h: No such file or directory
  ```
- investigation:
  ```shell
  $ awk '$5 == "python" || $5 == "readline" { print $0 }' config/crosscli/packages
  X 0-2------- 102.300 python python 3.13.5 / base/development CROSS NO-PIE NO-SSP NO-LTO.mips NO-LTO.mips64 NO-LTO.clang 0
  X --2------- 104.100 base readline 8.3-001 / base/library CROSS DIETLIBC FAT-LTO.mips FAT-LTO.mips64 0
  ```
- same problem (104.100 is greater than 102.300 so readline would be build "after" python - which is too late), so again:
  ```shell
  t2 build-target -cfg crosscli 2-readline
  # resume build
  t2 build-target -cfg crosscli
  ```


Next error:
- stage `2-base/pam`
  ```
  doc/man/meson.build:42:2: ERROR: Command `/usr/src/t2-src/build/crosscli-25-svn-generic-x86-64-nocona-cross-linux/TOOLCHAIN/cross/bin/xmllint
  ```
- real error from log seems to be:
  ```
  I/O warning : failed to load "http://docbook.org/xml/5.0/rng/docbookxi.rng": No such file or directory
  Relax-NG parser error : xmlRelaxNGParse: could not load http://docbook.org/xml/5.0/rng/docbookxi.rng
  Relax-NG schema http://docbook.org/xml/5.0/rng/docbookxi.rng failed to compile
  ```
- I added `docbook-xml` to config, but not sure, but it seems that just on Host system:
  ```shell
  t2 install docbook-xml
  ```
  fixed it(?)
- and resume build with:
  ```shell
  t2 build-target -cfg crosscli
  ```

Much later
- error on `2-filesystem/squashfs-tools`
  ```
  lz4_wrapper.c:27:10: fatal error: lz4.h: No such file or directory
  ```
- fixed in 15-cli


When above build finishes, create `crosscli.iso` and `crosscli.sha256` using:

```shell
t2 create-iso crosscli
```

It will create `crosscli.*` files right under `/usr/src/t2-src/`.

ISO Image tested on 2025-08-03:
- `curl(1)` works fine - it has its own CA list in `/etc/curl/cacert.pem`
- other programs will likely NOT work with `https`, becuase I excluded
  `ca-certificates` to avoid dependency on Rust bloat.

# Cross base Wayland image - UNTESTED

Now testing cross-building Wayland image (basically same as official ISO but from
latest commit).

Tested commit:
```shell
$ cd /usr/src/t2-src
$ svn info | grep '^Last Changed'

Last Changed Author: rene
Last Changed Rev: 75092
Last Changed Date: 2025-03-15 22:57:37 +0100 (Sat, 15 Mar 2025)
```
Tested config is under [config/crosswland/](config/crosswland).

Commands so far:
```shell
t2 config -cfg crosswland
t2 install perl perl-xml-parser python python-installer setuptools pip jinja2 ninja meson libtool libxml autoconf
t2 build-target -cfg crosswland 0-scdoc
t2 build-target -cfg crosswland
# work in progress.. - will fail on  linux-firmware with: ERROR: the GNU parallel command is required to use -j
t2 install parallel
t2 build-target -cfg crosswland
# but GNU parallel will cause other error:
#   Created file outside basedir: /root/.parallel/tmp
# running it again fixes it (because these files already exists before build)

# have to fix rsync download from my project ..../hpaluch-pil/t2sde-patches/fix_rsync_mirror.sh
# and run again
t2 build-target -cfg crosswland
# new error: Program 'mesa_clc' not found or not executable
# trying:
t2 install mesa # answer 'y' to all questions
# resume cross-build
t2 build-target -cfg crosswland
# 2-serf: scons not found
t2 install scons
# 2-openjdk - requires zip
t2 install zip
# gnome/gtk+ - vanished file errors - simply re-run build
# but next: 2-librsvg - requires cargo-cbuild
t2 install cargo-c
...
```

# Minimalist "embedded" image - UNTESTED

I'm now testing cross-build of really minimalist image for `x86_64` - just 16 packages
to be (cross) build.

> [!WARNING]
>
> Work in progress.

To use it:
- tested on following T2SDE revision:
  ```shell
  $ cd /usr/src/t2-src
  $ svn info | grep '^Last Changed'

  Last Changed Author: notag
  Last Changed Rev: 75040
  Last Changed Date: 2025-03-13 22:39:45 +0100 (Thu, 13 Mar 2025)
  ```
- copy contents from [config/crossmin/](config/crossmin/) under
  your `/usr/src/t2-src`
- run this command (as root) to invoke cross-build:
  ```shell
  cd /usr/src/t2-src
  # run command below to review settings
  t2 config -cfg crossmin
  # run command below to cross-build truly minimal image
  t2 build-target -cfg crossmin
  ```
- you will likely encounter error while building `2-linux`, which means
  stage 2, package `linux` (kernel)
  ```
  /usr/src/t2-src/package/kernel/linux/linux.conf:
     line 176: x86_64-t2-linux-uclibc-depmod: command not found
  ```
- trying to fix with:
  ```shell
  vim config/crossmin/packages # enable scdoc for 02
  t2 build-target -cfg crossmin 0-scdoc
  t2 build-target -cfg crossmin 0-kmod
  # restart build of kernel
  t2 build-target -cfg crossmin
  # will fail on missing /embutils, fixing with:
  # if embutils were already installed we must remove all packages
  # with conflicting files:
  mine -r -R build/crossmin-25-svn-embedded-minimal-x86-64-nocona-cross-linux/ embutils coreutils
  # must build coreutils first to force embutils to install into dedicated dir
  t2 build-target -cfg crossmin 2-coreutils
  # only now can build embutils (after coreutils)
  t2 build-target -cfg crossmin 2-embutils
  # additional required fixes:
  t2 build-target -cfg crossmin 1-zstd
  t2 build-target -cfg crossmin 2-fget
  t2 build-target -cfg crossmin 2-disktype
  t2 build-target -cfg crossmin 2-ipconfig
  t2 build-target -cfg crossmin 2-sed
  ( cd build/crossmin-25-svn-embedded-minimal-x86-64-nocona-cross-linux && cp bin/sed usr/embutils/sed )
  # now run Host mkinitrd with chroot (must be absolute path!)
  /sbin/mkinitrd -R `pwd`/build/crossmin-25-svn-embedded-minimal-x86-64-nocona-cross-linux
  # these are required for Image scripts: kbd pciutils ncurses
  t2 build-target -cfg crossmin 2-pciutils
  # but kbd fails with hard-error and ncurses is not there
  mkdir -p build/crossmin-25-svn-embedded-minimal-x86-64-nocona-cross-linux/etc/stone.d

  # TODO: Uuugh so many issues....
  t2 build-target -cfg crossmin
  ```

Note on configuration:
- I selected `Embedded minimal` that uses uClibc runtime with `busybox` for commands and `dropbear` for SSHD server
  for really minimal system - see `target/embedded*` under your source dir for configuration.
- I unchecked `Stack protection` because some  uLibc components has issues with it
- I always use `Abort build after stage (9)` which means "abort build in any stage"


# Random setup commands:

```shell
/usr/sbin/useradd -m -G wheel,video,audio,dialout -s /bin/bash USERNAME
passwd USERNAME
```

# Upgrading T2 from 25.1 to latest trunk - UNTESTED

Goal: upgrade to latest revision:

```shell
cd /usr/src/t2-src/
t2 up
t2 config # I just set "abort on build error"
t2 install perl perl-xml-parser python python-installer setuptools pip jinja2 ninja meson libtool libxml autoconf
t2 install btop mc
t2 upgrade
# handling failed packages/deps
ls -lrt /var/adm/logs/*.err

# rsync:
# problem with download - corrupted file:
file download/mirror/r/rsync-3.4.1.tar.gz.extck-err
# => download/mirror/r/rsync-3.4.1.tar.gz.extck-err: data
# should return gzip
# fixed with: found link on: https://www.linuxfromscratch.org/blfs/view/svn/basicnet/rsync.html
curl -fLo download/mirror/r/rsync-3.4.1.tar.gz  https://www.samba.org/ftp/rsync/src/rsync-3.4.1.tar.gz
file download/mirror/r/rsync-3.4.1.tar.gz
# => download/mirror/r/rsync-3.4.1.tar.gz: gzip compressed data, ...
rm download/mirror/r/rsync-3.4.1.tar.gz.extck-err
# again try build it:
t2 install rsync

# cryptsetup - just missing deps (base-wayland installation have not developemnt deps):

# now tough stuff - rustc
# see https://github.com/rxrbln/t2sde/pull/211 for details
mine -r rustc
# download and copy my patch: package/rust/rustc/rustdriver-libz-fix.patch
# and then: (takes around 15minutes on 10cores 12threads)
t2 install rustc
t2 clean # remove all aborted builds
# ok resume upgrade
t2 install mesa # install lot of build deps
t2 install thunderbird # same
t2 upgrade
t2 install libxfce4windowing # same - install deps

# new update
t2 up
svn info | grep '^Last Changed' | cut -d ' ' -f 4- | tr '\n' ' ';echo
# => foxdrodd 74894 2025-03-09 11:00:15 +0100 (Sun, 09 Mar 2025)

# we have to enable introspection and rebuild all packages
# that wil generate .gir files, following https://t2sde.org/kb/8/
t2 install -f gobject-introspection gdk-pixbuf pango harfbuzz at-spi2-core graphene gtk
# new addition:
t2 install -f libxfce4util
t2 upgrade

# corrupted icu4c mirror:
curl -fLo download/mirror/i/icu4c-75_1-data.zip https://github.com/unicode-org/icu/releases/download/release-75-1/icu4c-75_1-data.zip
file download/mirror/i/icu4c-75_1-data.zip
rm -f download/mirror/i/icu4c-75_1-data.zip.extck-err
# force installation of build deps:
t2 install libreoffice

t2 upgrade
```


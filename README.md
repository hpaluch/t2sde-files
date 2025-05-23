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

> [!WARNING!
> I have to remove `ca-certificates`, because even those now depends on Rust.
> It means that target system will not trust standard certificates (so `curl`
> will need `-k` parameter to accept them).

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
Last Changed Rev: 77265
Last Changed Date: 2025-05-19 13:22:05 +0200 (Mon, 19 May 2025)

# I need git and mc :-)

$ t2 install -optional-deps=no git mc

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

You may get error
- on building `5-python/python-installer`:
  ```
  ! scripts/functions.in: line 842: unzip: command not found
  ```
- that's because `unzip` is build after `python-installer` (higher priority number):
  ```shell
  $ grep -Ew '(unzip|python-installer)' config/crosscli/packages 

  X -----5---- 109.001 python python-installer 0.7.0 / extra/development CROSS 0
  X 0----5---- 110.600 archiver unzip 60 / base/tool CROSS 0
  ```
- workaround:
  ```shell
  t2 build-target -cfg crosscli 5-unzip
  t2 build-target -cfg crosscli
  ```
- same for `scons` when building `5-serf`:
  ```shell
  t2 build-target -cfg crosscli 5-scons
  t2 build-target -cfg crosscli
  ```

- again missing `strip` fix:
  ```shell
  ( cd build/crosscli-25-svn-generic-x86-64-nocona-linux/usr/bin &&
    ln -s strip x86_64-t2-linux-gnu-strip )
  ```

- TODO: Resolve failure on `5-t2-src`


When above build finishes, create `crosscli.iso` and `crosscli.sha256` using:

```shell
t2 create-iso crosscli
```

It will create `crosscli.*` files right under `/usr/src/t2-src/`.

TODO: Test ISO

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


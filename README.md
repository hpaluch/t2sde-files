# My configs for T2SDE Linux

Without any warranty!

Please see:
* official homepage of T2SDE Linux: https://t2sde.org/
* my wiki: https://github.com/hpaluch/hpaluch.github.io/wiki/T2SDE

# Minimalist image

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
  t2 build-target -cfg crossmin 2-kmod
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

# Upgrading T2 from 25.1 to latest trunk

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


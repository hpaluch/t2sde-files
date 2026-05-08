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

I installed latest T2 version 26.3 from `t2-26.3-x86-64-desktop.iso`. Then did preparation.

Here are details of cross-build:

```shell
$ cd /usr/src/t2-src/
$ t2 up
$ svn info | grep '^Last Change'

Last Changed Author: data
Last Changed Rev: 91112
Last Changed Date: 2026-05-07 19:06:16 +0200 (Thu, 07 May 2026)

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
SDECFG_X8664_OPT='nocona' # or just 'generic'
SDECFG_CROSSBUILD='1'
SDECFG_CONTINUE_ON_ERROR_AFTER='9
# update for and later: r77109, 12 May 2025
# required to avoid 1-gcc build errors:
# config: GCC Options -> UNCHECK "Enable GNAT"
SDECFG_PKG_GCC_GNAT='0'
```

Build image with:

```shell
t2 build-target -cfg crosscli
```
Total 216 packages to be build.

New error (T2SDE 26.3, 2026-04-12):
- glib:
  ```
  [57/704] Compiling C object glib/libglib-2.0.so.0.8800.0.p/gmessages.c.o
  ! ninja: build stopped: subcommand failed.
  ! Due to previous errors, no 0-glib.log file!
  ```
- some hint is in `build/crosscli-26-svn-generic-x86-64-linux/var/adm/logs/0-glib.err`
- cause: `free_sized(3)` is enabled for `C23` standard only, but glib is build with `GNU99`
  standard. But detection is buggy: symbol `free_sized` is always available (tested by Meson),
  but header defines it only for C23 standard - so this leads to Implicit function declaration
  error.
- workaround: copy `patches/hotfix-free-sized.patch` to `/usr/src/t2-src/package/gnome/glib`
  and build again

New error:
- on `2-firmware/linux-firmware`
  ```
  ! ERROR: the GNU parallel command is required to use -j
  ```
- workaround: apply

```diff
Index: package/firmware/linux-firmware/linux-firmware.desc
===================================================================
--- package/firmware/linux-firmware/linux-firmware.desc	(revision 91125)
+++ package/firmware/linux-firmware/linux-firmware.desc	(working copy)
@@ -26,6 +26,7 @@
 
 noorphaned=1 makeopt=
 #makeinstopt="${makeinstopt/install/install-nodedup}"
+var_remove makeinstopt ' ' '-j*'
 
 [[ $arch = x86* ]] || hook_add premake 2 "sed -i /amd-ucode/d WHENCE"
```

And run: `t2 build-target -cfg crosscli 2-linux-firmware`


New readline error (different):
```
12:24:22 1/282 Building 5-base/readline (8.3.3) ~3s
bash: error while loading shared libraries: libhistory.so.8: cannot open shared object file: No such file or directory
bash: error while loading shared libraries: libhistory.so.8: cannot open shared object file: No such file or directory
! bash: error while loading shared libraries: libhistory.so.8: cannot open shared object file: No such file or directory
! bash: error while loading shared libraries: libhistory.so.8: cannot open shared object file: No such file or directory
! mv /usr/lib64/libreadline.a /usr/lib64/libreadline.old
! bash: error while loading shared libraries: libhistory.so.8: cannot open shared object file: No such file or directory
! /TOOLCHAIN/build/crosscli-26-svn-generic-x86-64-linux/TOOLCHAIN/tools.chroot/wrapper/install -c -m 644 libreadline.a /usr/lib64/libreadline.a
! bash: error while loading shared libraries: libhistory.so.8: cannot open shared object file: No such file or directory
! Due to previous errors, no 5-readline.log file!
! (Try enabling xtrace in the config to track an error inside the build system.)
```
- quick workaround
- workaround: copy `patches/hotfix-free-sized.patch` to `/usr/src/t2-src/package/base/readline/`
- first - restore completely broken system:
  ```shell
  t2 clean
  mv build/crosscli-26-svn-generic-x86-64-linux/usr/lib64/libhistory.so.8.3{.old,}
  # now should proceed
  t2 build-target -cfg crosscli 5-readline
  ```

Next error - applies also for (T2SDE 26.3, 2026-04-12):
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

Hmm, next error - applies also for (T2SDE 26.3, 2026-04-12):
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

New fine error (T2SDE 26.3, 2026-04-12):
- error:
  ```
 File not found: download/mirror/n/netkit-base-0.17.tar.gz
  Did you run scripts/Download for this package?
! Due to previous errors, no 2-netkit-base.log file!
! (Try enabling xtrace in the config to track an error inside the build system.)
  +00:00:06 Aborted building network/netkit-base
  ```
- workaround:
  ```shell
  curl -fL -o /usr/src/t2-src/download/mirror/n/netkit-base-0.17.tar.gz \
    https://ftp.gwdg.de/pub/linux/misc/linux.org.uk/people/linux/Networking/netkit/netkit-base-0.17.tar.gz
  file /usr/src/t2-src/download/mirror/n/netkit-base-0.17.tar.gz
  # => /usr/src/t2-src/download/mirror/n/netkit-base-0.17.tar.gz: gzip compressed data, last modified: Mon Jul 31 00:10:39 2000, from Unix, original size modulo 2^32 225280
  ```

And another new error:
- error:
  ```
    Creating build/crosscli-26-svn-generic-x86-64-linux/TOOLCHAIN/pkgs/rocknet-2024-09-19.tar.zst
  ! Removing CVS, .svn, {arch} and .arch-ids directories ...
  ! Changing into /usr/src/t2-src/src.groff.crosscli.260412.184451.829763/groff-1.24.1 ...
  ! Applying /usr/src/t2-src/package/textproc/groff/configure-csh.patch.cross
  ! patching file configure
  ! Hunk #1 FAILED at 25337.
  ! 1 out of 1 hunk FAILED -- saving rejects to file configure.rej
  ! Due to previous errors, no 2-groff.log file!
  ! (Try enabling xtrace in the config to track an error inside the build system.)
    +00:00:05 Aborted building textproc/groff
  ```
- dirty workaround:
  ```shell
  mv package/textproc/groff/configure-csh.patch.cross /root/
  ```
- but it will again fail - on script test-groff:
  ```
  ! sh: test-groff: inaccessible or not found
  ! pdfmom: fatal error: test-groff exited with status 127                                                                ! sh: test-groff: inaccessible or not found
  ! pdfmom: fatal error: test-groff exited with status 127                                                                ! Due to previous errors, no 2-groff.log file!
  ! (Try enabling xtrace in the config to track an error inside the build system.)
    +00:00:34 Aborted building textproc/groff
  ```
- fix: copy `patches/hotfix-test-groff-path.patch` to `/usr/src/t2-src/package/textproc/groff/hotfix-test-groff-path.patch` and run build again

But now there is new error in tests (making debug output in test-groff script):
```
XXXX: /TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/groff -Tpdf -mom -Kutf8 - -F/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/font -F/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/font -M/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/tmac -M/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/tmac -M./contrib/mom -p -e -t -wall -b -P-W contrib/mom/examples/typesetting.mom
XXXX: /TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/groff -Tpdf -dLABEL.REFS=1 -mom -z -F/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/font -F/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/font -M/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/tmac -M/TOOLCHAIN/src.groff.crosscli.260508.142913.2834574/groff-1.24.1/tmac -M./contrib/mom -p -e -t -wall -b -P-W contrib/mom/examples/typesetting.mom
gropdf: warning: The download file in '/usr/share/groff/1.24.1/font/devpdf' has erroneous entry for 'NewCenturySchlbk-Roman (NR)'
gropdf: warning: The download file in '/usr/share/groff/1.24.1/font/devpdf' has erroneous entry for 'NewCenturySchlbk-Bold (NB)'
gropdf: warning: The download file in '/usr/share/groff/1.24.1/font/devpdf' has erroneous entry for 'Palatino-Roman (PR)'
gropdf: warning: The download file in '/usr/share/groff/1.24.1/font/devpdf' has erroneous entry for 'Palatino-Italic (PI)'
pdfmom: fatal error: ./test-groff exited with status 4
make[2]: *** [Makefile:19228: contrib/mom/examples/typesetting.pdf] Error 1
make[2]: *** Deleting file 'contrib/mom/examples/typesetting.pdf'
```
Solution: apply following new patch:
- `cp hotfix-groff-remove-palatino.patch patches//usr/src/t2-src/package/textproc/groff/`
- test Groff build: `t2 build-target -cfg crosscli 5-groff`
- on success resume with `t2 build-target -cfg crosscli`

New error in: `5-python/jinja2`
```
! ModuleNotFoundError: No module named 'flit_core'
! Due to previous errors, no 5-jinja2.log file!
! (Try enabling xtrace in the config to track an error inside the build system.)
  +00:00:03 Aborted building python/jinja2
```
Workaround:
```shell
t2 build-target -cfg crosscli 5-python-flit-core
t2 build-target -cfg crosscli 5-jinja2
t2 build-target -cfg crosscli
```

Another problem: `5-network/serf`
```
Running scons --jobs 12 CC=gcc PREFIX=/usr LIBDIR=/usr/lib64 APR=/usr/bin/apr-1-config APU=/usr/bin/apu-1-config
! scripts/functions.in: line 1120: scons: command not found
```
Workaround:
```shell
t2 build-target -cfg crosscli 5-scons
t2 build-target -cfg crosscli 5-serf
t2 build-target -cfg crosscli
```

Next error - still applies:
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

New error:
- error:
  ```
  ! Consider adjusting the PKG_CONFIG_PATH environment variable if you
  ! installed software in a non-standard prefix.
  ! Alternatively, you may set the environment variables UDEV_CFLAGS
  ! and UDEV_LIBS to avoid the need to call pkg-config.
  ! See the pkg-config man page for more details.
  ! Due to previous errors, no 2-lvm2.log file!
  ! (Try enabling xtrace in the config to track an error inside the build system.)
    +00:00:01 Aborted building filesystem/lvm2
  ```
- log `build/crosscli-26-svn-generic-x86-64-linux/var/adm/logs/2-lvm2.err` reveals:
  ```
  configure: error: Package requirements (libudev >= 143) were not met:
  No package 'libudev' found
  ```
- trying:
  ```shell
  t2 build-target -cfg crosscli 2-udev
  t2 build-target -cfg crosscli # resume build
  ```

Another error:
- error:
  ```
  20:32:11 197/216 Building 2-security/ca-certificates (20260223) ~1s
  ! done
  ! python3 certdata2pem.py
  ! Traceback (most recent call last):
  !   File "/usr/src/t2-src/src.ca-certificates.crosscli.260412.203211.1319550/ca-certificates/mozilla/certdata2pem.py ..
  !     from cryptography import x509
  ! ModuleNotFoundError: No module named 'cryptography'
  ! Due to previous errors, no 2-ca-certificates.log file!
  ! (Try enabling xtrace in the config to track an error inside the build system.)
    +00:00:15 Aborted building security/ca-certificates
  Aborting due to failure.
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

# Notes

Building nvi (for fixfiles):
- must use archive.org:
  ```shell
  curl -fL -o download/mirror/n/nvi-1.81.6.tar.xz https://web.archive.org/web/20241213183854if_/https://fossies.org/linux/privat/old/nvi-1.81.6.tar.xz
  file download/mirror/n/nvi-1.81.6.tar.xz
  # => download/mirror/n/nvi-1.81.6.tar.xz: XZ compressed data, checksum CRC64
  ```

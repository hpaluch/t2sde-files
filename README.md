# My configs for T2SDE Linux

Without any warranty!

Please see:
* official homepage of T2SDE Linux: https://t2sde.org/
* my wiki: https://github.com/hpaluch/hpaluch.github.io/wiki/T2SDE

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
```

 

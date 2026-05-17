#!/bin/bash
# prepare t2 linux for building
set -euo pipefail

# error and exit (BSD like function)
errx () { echo "ERROR: $*" >&2; exit 1; }

s=$(readlink -f $0)
# d= directory of this script
d=$(dirname "$s")
echo "d=$d"
[ -d "$d" ] || errx "internal error: resolved '$d' is not directory"

set -x
cd /usr/src/t2-src
[ -f config/default/config ] || t2 up
which mc || t2 install -optional-deps=no git mc btop 

# We must install packages from: https://t2linux.com/documentation/kb/8/?documentation/kb/8
# Additionally we need:
# - scons required by serf which is http(s) library for SVN client
# - mtools required for image creation script
# - scdoc still required by kmod under some circumstances
which scdoc || t2 install -optional-deps=no perl perl-xml-parser python python-installer setuptools \
     pip jinja2 ninja meson libtool libxml autoconf scons mtools scdoc
x=target/generic/pkgsel/15-cli.in
[ -f "$x" ] || cp -v $d/$x $x
exit 0

#!/bin/bash
# cross-build my CLI profile (config=crosscli)
set -euo pipefail

# our config name:
c=crosscli
s=/usr/src/t2-src

# error and exit (BSD like function)
errx () { echo "ERROR: $*" >&2; exit 1; }

is_uptodate () {
	dst="$1"
	src="$2"
	[ -f "$src" ] || errx "Source file '$src' does not exist"
	[ -f "$dst" ] || {
		echo "INFO: $dst : $src # $dst does not exist: triggering build"
		return 1
	}
	mtime_src=$(stat -c '%Y' "$src")
	mtime_dst=$(stat -c '%Y' "$dst")
	mtime_diff=$(( mtime_dst - mtime_src ))
	[ "$mtime_diff" -ge 0 ] || {
		echo "INFO: $dst : $src # $dst out-of-date $mtime_diff seconds: triggering rebuild"
		return 1
	}
	return 0
}

ss=$(readlink -f $0)
# d= directory of this script
d=$(dirname "$ss")
unset ss
echo "d=$d"
[ -d "$d" ] || errx "internal error: resolved '$d' is not directory"

cd $s
x=target/generic/pkgsel/15-cli.in
[ -f "$x" ] || errx "Missing $s/$x file. Run ./t2-bootstrap.sh first."

cf=$s/config/$c/config

is_uptodate "$cf" "$x" || {
	# setup new custom config
	config=$c
	set -x
	# NOTE: please just exit this program
	t2 config -cfg $c
	t2 config -cfg $c PKGSEL_TMPL=cli X8664_OPT=generic \
		CROSSBUILD=1 CONTINUE_ON_ERROR_AFTER=9 PKG_GCC_GNAT=0 TMPFS=0 \
		TARGET=generic
	set +x
}

# fix known build errors
error_path=$(echo build/$c-*-svn-generic-x86-64-linux/var/adm/logs/*.err)
if [ -f "$error_path" ] ; then
error_file=${error_path##*/}
error="${error_file%.err}"
echo "Detected error '$error'"
case "$error" in
	0-glib)
		set -x
		cp -v $d/patches/hotfix-free-sized.patch $s/package/gnome/glib/
		t2 build-target -cfg $c $error
		set +x
		;;
	2-netkit-base)
		set -x
		f=$s/download/mirror/n/netkit-base-0.17.tar.gz
	  curl -fL -o  $f \
	    https://ftp.gwdg.de/pub/linux/misc/linux.org.uk/people/linux/Networking/netkit/netkit-base-0.17.tar.gz
	  file $f | fgrep gzip || errx "Downloaded file '$f is invalid - not gzip compressed file"
	  t2 build-target -cfg $c $error
	  set +x
		;;
	2-pam)
		set -x
		  t2 install docbook-xml
		  t2 build-target -cfg $c $error
		set +x
		;;
	*) errx "Unknown error '$error' occured - unable to continue"
	       	;;
esac
t2 build-target -cfg $c
fi # build error handling

# detect outdated: $s/build/$c-26-svn-generic-x86-64-linux/TOOLCHAIN/isofs.txt as trigger
dst=$(echo build/$c-26-svn-generic-x86-64-linux/TOOLCHAIN/isofs.txt)
is_uptodate $dst $cf || t2 build-target -cfg $c
# detect outdated $s/$c.iso as trigger
is_uptodate $s/$c.iso $dst || t2 create-iso $c
echo "OK: finished. ISO written to $s/$c.iso"
ls -lhs $s/$c.iso
exit 0

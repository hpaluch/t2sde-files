#!/bin/bash
# cross-build my CLI profile (config=crosscli)
# WORK IN PROGRESS - NOT FINISHED YET.
set -euo pipefail

# our config name:
c=crosscli
s=/usr/src/t2-src

# error and exit (BSD like function)
errx () { echo "ERROR: $*" >&2; exit 1; }

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

[ -f "$cf" ] || errx "TODO: configure -config=$c"

# fix known build errors
error_path=$(echo build/$c-*-svn-generic-x86-64-linux/var/adm/logs/*.err)
[ -f "$error_path" ] || errx "Unable to detect error file, got '$error_path'"
error_file=${error_path##*/}
error="${error_file%.err}"
echo "Detected error '$error'"
case "$error" in
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
set -x
t2 build-target -cfg $c


exit 0

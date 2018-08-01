# Copyright (C) 2012 Jonathan Chu <milki@rescomp.berkeley.edu>. All Rights Reserved.
# Copyright (C) 2015 David Dahlberg <david.dahlberg@fkie.fraunhofer.de>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

tmpdir() {
	[[ -n $SECURE_TMPDIR ]] && return
	local warn=1
	[[ $1 == "nowarn" ]] && warn=0
	local template="$PROGRAM.XXXXXXXXXXXXX"
	if [[ $(sysctl -n kern.usermount) == 1 ]]; then
		SECURE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/$template")"
		mount -t tmpfs -o -s16M tmpfs "$SECURE_TMPDIR" || die "Error: could not create tmpfs."
		unmount_tmpdir() {
			 [[ -n $SECURE_TMPDIR && -d $SECURE_TMPDIR ]] || return
			 umount "$SECURE_TMPDIR"
			 rm -rf "$SECURE_TMPDIR"
		}
		trap unmount_tmpdir INT TERM EXIT
	else
		[[ $warn -eq 1 ]] && yesno "$(cat <<-_EOF
		The sysctl kern.usermount is disabled, therefore it is not
		possible to create a tmpfs for temporary storage of files
		in memory.
		This means that it may be difficult to entirely erase
		the temporary non-encrypted password file after editing.

		Are you sure you would like to continue?
		_EOF
		)"
		SECURE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/$template")"
		shred_tmpfile() {
			find "$SECURE_TMPDIR" -type f -exec $SHRED {} +
			rm -rf "$SECURE_TMPDIR"
		}
		trap shred_tmpfile INT TERM EXIT
	fi
}

GETOPT="gnugetopt"
SHRED="rm -P -f"
BASE64="openssl base64"

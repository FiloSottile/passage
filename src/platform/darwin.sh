# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

clip() {
	local sleep_argv0="password store sleep for user $(id -u)"
	pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
	local before="$(pbpaste | openssl base64)"
	echo -n "$1" | pbcopy
	(
		( exec -a "$sleep_argv0" sleep "$CLIP_TIME" )
		local now="$(pbpaste | openssl base64)"
		[[ $now != $(echo -n "$1" | openssl base64) ]] && before="$now"
		echo "$before" | openssl base64 -d | pbcopy
	) 2>/dev/null & disown
	echo "Copied $2 to clipboard. Will clear in $CLIP_TIME seconds."
}

tmpdir() {
	[[ -n $SECURE_TMPDIR ]] && return
	unmount_tmpdir() {
		[[ -n $SECURE_TMPDIR && -d $SECURE_TMPDIR && -n $DARWIN_RAMDISK_DEV ]] || return
		umount "$SECURE_TMPDIR"
		diskutil quiet eject "$DARWIN_RAMDISK_DEV"
		rm -rf "$SECURE_TMPDIR"
	}
	trap unmount_tmpdir INT TERM EXIT
	SECURE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/$PROGRAM.XXXXXXXXXXXXX")"
	DARWIN_RAMDISK_DEV="$(hdid -drivekey system-image=yes -nomount 'ram://32768' | cut -d ' ' -f 1)" # 32768 sectors = 16 mb
	[[ -z $DARWIN_RAMDISK_DEV ]] && die "Error: could not create ramdisk."
	newfs_hfs -M 700 "$DARWIN_RAMDISK_DEV" &>/dev/null || die "Error: could not create filesystem on ramdisk."
	mount -t hfs -o noatime -o nobrowse "$DARWIN_RAMDISK_DEV" "$SECURE_TMPDIR" || die "Error: could not mount filesystem on ramdisk."
}

GETOPT="$(brew --prefix gnu-getopt 2>/dev/null || { which port &>/dev/null && echo /opt/local; } || echo /usr/local)/bin/getopt"
SHRED="srm -f -z"

# Copyright (C) 2012 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

clip() {
	before="$(pbpaste | openssl base64)"
	echo -n "$1" | pbcopy
	(
		sleep 45
		now="$(pbpaste | openssl base64)"
		if [[ $now != $(echo -n "$1" | openssl base64) ]]; then
			before="$now"
		fi
		echo "$before" | openssl base64 -d | pbcopy
	) & disown
	echo "Copied $2 to clipboard. Will clear in 45 seconds."
}

tmpdir() {
	cleanup_tmp() {
		[[ -d $tmp_dir ]] || return
		rm -rf "$tmp_file" "$tmp_dir" 2>/dev/null
		umount "$tmp_dir"
		diskutil quiet eject "$ramdisk_dev"
		rmdir "$tmp_dir"
	}
	trap cleanup_tmp INT TERM EXIT
	tmp_dir="$(mktemp -t "$template" -d)"
	ramdisk_dev="$(hdid -drivekey system-image=yes -nomount 'ram://32768' | cut -d ' ' -f 1)" # 32768 sectors = 16 mb
	[[ -z $ramdisk_dev ]] && exit 1
	newfs_hfs -M 700 "$ramdisk_dev" &>/dev/null || exit 1
	mount -t hfs -o noatime -o nobrowse "$ramdisk_dev" "$tmp_dir" || exit 1
}

GPG="gpg2"
GETOPT="$(brew --prefix gnu-getopt 2>/dev/null || echo /usr/local)/bin/getopt"

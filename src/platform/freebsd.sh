# Copyright (C) 2012 Jonathan Chu <milki@rescomp.berkeley.edu>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

tmpdir() {
	ramdisk="/var/tmp/password-store.ramdisk"
	if [[ -d $ramdisk && -d $ramdisk && -d $ramdisk ]]; then
		tmp_dir="$(TMPDIR=$ramdisk mktemp -t "$template" -d)"
	else
		yesno "$(echo    "A ramdisk does not exist at $ramdisk, which means that it may"
			 echo    "be difficult to entirely erase the temporary non-encrypted"
			 echo    "password file after editing. Are you sure you would like to"
			 echo -n "continue?")"

		tmp_dir="$(mktemp -t "$template" -d)"
	fi
}

GETOPT="/usr/local/bin/getopt"
SHRED="rm -P -f"

tmpdir() {
    ramdisk="/var/tmp/password-store.ramdisk"
    if [[ -d $ramdisk && -d $ramdisk && -d $ramdisk ]]; then
		tmp_dir="$(TMPDIR=$ramdisk mktemp -t "$template" -d)"
	else
		yesno "$(cat <<PROMPT
A ramdisk does not exist at

    $ramdisk

which means that it may be difficult to entirely erase
the temporary non-encrypted password file after editing.
Are you sure you would like to continue?
PROMPT
)"
		tmp_dir="$(mktemp -t "$template" -d)"
	fi
}

GPG="gpg2"
GETOPT="/usr/local/bin/getopt"

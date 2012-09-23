#!/bin/bash

# Copyright (C) 2012 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

umask 077

PREFIX="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
ID="$PREFIX/.gpg-id"
GIT_DIR="${PASSWORD_STORE_GIT:-$PREFIX}/.git"
GPG_OPTS="--quiet --yes --batch"

export GIT_DIR
export GIT_WORK_TREE="${PASSWORD_STORE_GIT:-$PREFIX}"

version() {
	cat <<_EOF
|-----------------------|
|   Password Store      |
|         v.1.4         |
|       by zx2c4        |
|                       |
|    Jason@zx2c4.com    |
|  Jason A. Donenfeld   |
|-----------------------|
_EOF
}
usage() {
	version
	cat <<_EOF

Usage:
    $program init [--reencrypt,-e] gpg-id
        Initialize new password storage and use gpg-id for encryption.
        Optionally reencrypt existing passwords using new gpg-id.
    $program [ls] [subfolder]
        List passwords.
    $program [show] [--clip,-c] pass-name
        Show existing password and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in 45 seconds.
    $program insert [--no-echo,-n | --multiline,-m] [--force,-f] pass-name
        Insert new password. Optionally, the console can be enabled to not
        echo the password back. Or, optionally, it may be multiline. Prompt
        before overwriting existing password unless forced.
    $program edit pass-name
        Insert a new password or edit an existing password using ${EDITOR:-vi}.
    $program generate [--no-symbols,-n] [--clip,-c] [--force,-f] pass-name pass-length
        Generate a new password of pass-length with optionally no symbols.
        Optionally put it on the clipboard and clear board after 45 seconds.
        Prompt before overwriting existing password unless forced.
    $program rm [--recursive,-r] [--force,-f] pass-name
        Remove existing password or directory, optionally forcefully.
    $program git git-command-args...
        If the password store is a git repository, execute a git command
        specified by git-command-args.
    $program help
        Show this text.
    $program version
        Show version information.

More information may be found in the pass(1) man page.
_EOF
}
is_command() {
	case "$1" in
		init|ls|list|show|insert|edit|generate|remove|rm|delete|git|help|--help|version|--version) return 0 ;;
		*) return 1 ;;
	esac
}
git_add_file() {
	[[ -d $GIT_DIR ]] || return
	git add "$1" || return
	[[ -n $(git status --porcelain "$1") ]] || return
	git commit -m "$2"
}
yesno() {
	read -p "$1 [y/N] " response
	[[ $response == "y" || $response == "Y" ]] || exit 1
}
#
# BEGIN Platform definable
#
clip() {
	# This base64 business is a disgusting hack to deal with newline inconsistancies
	# in shell. There must be a better way to deal with this, but because I'm a dolt,
	# we're going with this for now.

	before="$(xclip -o -selection clipboard | base64)"
	echo -n "$1" | xclip -selection clipboard
	(
		sleep 45
		now="$(xclip -o -selection clipboard | base64)"
		if [[ $now != $(echo -n "$1" | base64) ]]; then
			before="$now"
		fi

		# It might be nice to programatically check to see if klipper exists,
		# as well as checking for other common clipboard managers. But for now,
		# this works fine -- if qdbus isn't there or if klipper isn't running,
		# this essentially becomes a no-op.
		#
		# Clipboard managers frequently write their history out in plaintext,
		# so we axe it here:
		qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null

		echo "$before" | base64 -d | xclip -selection clipboard
	) & disown
	echo "Copied $2 to clipboard. Will clear in 45 seconds."
}
tmpdir() {
	if [[ -d /dev/shm && -w /dev/shm && -x /dev/shm ]]; then
		tmp_dir="$(TMPDIR=/dev/shm mktemp -t "$template" -d)"
	else
		yesno "$(echo    "Your system does not have /dev/shm, which means that it may"
		         echo    "be difficult to entirely erase the temporary non-encrypted"
		         echo    "password file after editing. Are you sure you would like to"
		         echo -n "continue?")"
		tmp_dir="$(mktemp -t "$template" -d)"
	fi

}
GPG="gpg"
GETOPT="getopt"

# source /path/to/platform-defined-functions
#
# END Platform definable
#

program="$(basename "$0")"
command="$1"
if is_command "$command"; then
	shift
else
	command="show"
fi

case "$command" in
	init)
		reencrypt=0

		opts="$($GETOPT -o e -l reencrypt -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-e|--reencrypt) reencrypt=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command [--reencrypt,-e] gpg-id"
			exit 1
		fi

		gpg_id="$1"
		mkdir -v -p "$PREFIX"
		echo "$gpg_id" > "$ID"
		echo "Password store initialized for $gpg_id."
		git_add_file "$ID" "Set GPG id to $gpg_id."

		if [[ $reencrypt -eq 1 ]]; then
			find "$PREFIX" -iname '*.gpg' | while read passfile; do
				$GPG -d $GPG_OPTS "$passfile" | $GPG -e -r "$gpg_id" -o "$passfile.new" $GPG_OPTS &&
				mv -v "$passfile.new" "$passfile"
			done
			git_add_file "$PREFIX" "Reencrypted entire store using new GPG id $gpg_id."
		fi
		exit 0
		;;
	help|--help)
		usage
		exit 0
		;;
	version|--version)
		version
		exit 0
		;;
esac

if [[ -n $PASSWORD_STORE_KEY ]]; then
	ID="$PASSWORD_STORE_KEY"
elif [[ ! -f $ID ]]; then
	echo "You must run:"
	echo "    $program init your-gpg-id"
	echo "before you may use the password store."
	echo
	usage
	exit 1
else
	ID="$(head -n 1 "$ID")"
fi

case "$command" in
	show|ls|list)
		clip=0

		opts="$($GETOPT -o c -l clip -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-c|--clip) clip=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 ]]; then
			echo "Usage: $program $command [--clip,-c] [pass-name]"
			exit 1
		fi

		path="$1"
		if [[ -d $PREFIX/$path ]]; then
			if [[ -z $path ]]; then
				echo "Password Store"
			else
				echo $path
			fi
			tree --noreport "$PREFIX/$path" | tail -n +2 | sed 's/\(.*\)\.gpg$/\1/'
		else
			passfile="$PREFIX/$path.gpg"
			if [[ ! -f $passfile ]]; then
				echo "$path is not in the password store."
				exit 1
			fi
			if [[ $clip -eq 0 ]]; then
				exec $GPG -d $GPG_OPTS "$passfile"
			else
				clip "$($GPG -d $GPG_OPTS "$passfile" | head -n 1)" "$path"
			fi
		fi
		;;
	insert)
		multiline=0
		noecho=0
		force=0

		opts="$($GETOPT -o mnf -l multiline,no-echo,force -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-m|--multiline) multiline=1; shift ;;
			-n|--no-echo) noecho=1; shift ;;
			-f|--force) force=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || ( $multiline -eq 1 && $noecho -eq 1 ) || $# -ne 1 ]]; then
			echo "Usage: $program $command [--no-echo,-n | --multiline,-m] [--force,-f] pass-name"
			exit 1
		fi
		path="$1"
		passfile="$PREFIX/$path.gpg"

		[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

		mkdir -p -v "$PREFIX/$(dirname "$path")"

		if [[ $multiline -eq 1 ]]; then
			echo "Enter contents of $path and press Ctrl+D when finished:"
			echo
			$GPG -e -r "$ID" -o "$passfile" $GPG_OPTS
		elif [[ $noecho -eq 1 ]]; then
			while true; do
				read -p "Enter password for $path: " -s password
				echo
				read -p "Retype password for $path: " -s password_again
				echo
				if [[ $password == $password_again ]]; then
					$GPG -e -r "$ID" -o "$passfile" $GPG_OPTS <<<"$password"
					break
				else
					echo "Error: the entered passwords do not match."
				fi
			done
		else
			read -p "Enter password for $path: " -e password
			$GPG -e -r "$ID" -o "$passfile" $GPG_OPTS <<<"$password"
		fi
		git_add_file "$passfile" "Added given password for $path to store."
		;;
	edit)
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command pass-name"
			exit 1
		fi

		path="$1"
		mkdir -p -v "$PREFIX/$(dirname "$path")"
		passfile="$PREFIX/$path.gpg"
		template="$program.XXXXXXXXXXXXX"

		trap 'rm -rf "$tmp_dir" "$tmp_file"' INT TERM EXIT

		tmpdir #Defines $tmp_dir
		tmp_file="$(TMPDIR="$tmp_dir" mktemp -t "$template")"

		action="Added"
		if [[ -f $passfile ]]; then
			$GPG -d -o "$tmp_file" $GPG_OPTS "$passfile" || exit 1
			action="Edited"
		fi
		${EDITOR:-vi} "$tmp_file"
		while ! $GPG -e -r "$ID" -o "$passfile" $GPG_OPTS "$tmp_file"; do
			echo "GPG encryption failed. Retrying."
			sleep 1
		done
		git_add_file "$passfile" "$action password for $path using ${EDITOR:-vi}."
		;;
	generate)
		clip=0
		force=0
		symbols="-y"

		opts="$($GETOPT -o ncf -l no-symbols,clip,force -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-n|--no-symbols) symbols=""; shift ;;
			-c|--clip) clip=1; shift ;;
			-f|--force) force=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || $# -ne 2 ]]; then
			echo "Usage: $program $command [--no-symbols,-n] [--clip,-c] [--force,-f] pass-name pass-length"
			exit 1
		fi
		path="$1"
		length="$2"
		if [[ ! $length =~ ^[0-9]+$ ]]; then
			echo "pass-length \"$length\" must be a number."
			exit 1
		fi
		mkdir -p -v "$PREFIX/$(dirname "$path")"
		passfile="$PREFIX/$path.gpg"

		[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

		pass="$(pwgen -s $symbols $length 1)"
		[[ -n $pass ]] || exit 1
		$GPG -e -r "$ID" -o "$passfile" $GPG_OPTS <<<"$pass"
		git_add_file "$passfile" "Added generated password for $path to store."
		
		if [[ $clip -eq 0 ]]; then
			echo "The generated password to $path is:"
			echo "$pass"
		else
			clip "$pass" "$path"
		fi
		;;
	delete|rm|remove)
		recursive=""
		force=0

		opts="$($GETOPT -o rf -l recursive,force -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-r|--recursive) recursive="-r"; shift ;;
			-f|--force) force=1; shift ;;
			--) shift; break ;;
		esac done
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command [--recursive,-r] [--force,-f] pass-name"
			exit 1
		fi
		path="$1"

		passfile="$PREFIX/${path%/}"
		if [[ ! -d $passfile ]]; then
			passfile="$PREFIX/$path.gpg"
			if [[ ! -f $passfile ]]; then
				echo "$path is not in the password store."
				exit 1
			fi
		fi

		[[ $force -eq 1 ]] || yesno "Are you sure you would like to delete $path?"

		rm $recursive -f -v "$passfile"
		if [[ -d $GIT_DIR && ! -e $passfile ]]; then
			git rm -qr "$passfile"
			git commit -m "Removed $path from store."
		fi
		;;
	git)
		if [[ $1 == "init" ]]; then
			git "$@" || exit 1
			git_add_file "$PREFIX" "Added current contents of password store."
		elif [[ -d $GIT_DIR ]]; then
			exec git "$@"
		else
			echo "Error: the password store is not a git repository."
			exit 1
		fi
		;;
	*)
		usage
		exit 1
		;;
esac
exit 0

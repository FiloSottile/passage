#!/bin/bash

# (C) Copyright 2012 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This is released under the GPLv2+. Please see COPYING for more information.

umask 077

PREFIX="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
ID="$PREFIX/.gpg-id"
GIT="$PREFIX/.git"

export GIT_DIR="$GIT"
export GIT_WORK_TREE="$PREFIX"

usage() {
	cat <<_EOF
Password Store
by Jason Donenfeld
   Jason@zx2c4.com

Usage:
    $program init gpg-id
        Initialize new password storage and use gpg-id for encryption.
    $program [ls] [subfolder]
        List passwords.
    $program [show] [--clip,-c] pass-name
        Show existing password and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in 45 seconds.
    $program insert [--no-echo,-n | --multiline,-m] pass-name
        Insert new password. Optionally, the console can be enabled to not
        echo the password back. Or, optionally, it may be multiline.
    $program edit pass-name
        Insert a new password or edit an existing password using ${EDITOR:-vi}.
    $program generate [--no-symbols,-n] [--clip,-c] pass-name pass-length
        Generate a new password of pass-length with optionally no symbols.
        Optionally put it on the clipboard and clear board after 45 seconds.
    $program rm pass-name
        Remove existing password.
    $program push
        If the password store is a git repository, push the latest changes.
    $program pull
        If the password store is a git repository, pull the latest changes.
    $program git git-command-args...
        If the password store is a git repository, execute a git command
        specified by git-command-args.
    $program help
        Show this text.
_EOF
}
isCommand() {
	case "$1" in
		init|ls|list|show|insert|edit|generate|remove|rm|delete|push|pull|git|help|--help) return 0 ;;
		*) return 1 ;;
	esac
}
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
		# this works fine. Clipboard managers frequently write their history
		# out in plaintext, so we axe it here.
		qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory >/dev/null 2>&1
		echo "$before" | base64 -d | xclip -selection clipboard
	) & disown
	echo "Copied $2 to clipboard. Will clear in 45 seconds."
}
program="$(basename "$0")"
command="$1"
if isCommand "$command"; then
	shift
else
	command="show"
fi

case "$command" in
	init)
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command gpg-id"
			exit 1
		fi
		gpg_id="$1"
		mkdir -v -p "$PREFIX"
		echo "$gpg_id" > "$ID"
		echo "Password store initialized for $gpg_id."
		exit 0
		;;
	help|--help)
		usage
		exit 0
		;;
esac

if ! [[ -f $ID ]]; then
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

		opts="$(getopt -o c -l clip -n $program -- "$@")"
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
			if [[ $path == "" ]]; then
				echo "Password Store"
			else
				echo $path
			fi
			tree --noreport "$PREFIX/$path" | tail -n +2 | sed 's/\(.*\)\.gpg$/\1/'
		else
			passfile="$PREFIX/$path.gpg"
			if ! [[ -f $passfile ]]; then
				echo "$path is not in the password store."
				exit 1
			fi
			if [ $clip -eq 0 ]; then
				exec gpg -q -d --yes "$passfile"
			else
				clip "$(gpg -q -d --yes "$passfile" | head -n 1)" "$path"
			fi
		fi
		;;
	insert)
		ml=0
		noecho=0

		opts="$(getopt -o mn -l multiline,no-echo -n $program -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-m|--multiline) ml=1; shift ;;
			-n|--no-echo) noecho=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || ( $ml -eq 1 && $noecho -eq 1 ) || $# -ne 1 ]]; then
			echo "Usage: $program $command [--no-echo,-n | --multiline,-m] pass-name"
			exit 1
		fi
		path="$1"
		mkdir -p -v "$PREFIX/$(dirname "$path")"

		passfile="$PREFIX/$path.gpg"
		if [[ $ml -eq 1 ]]; then
			echo "Enter contents of $path and press Ctrl+D when finished:"
			echo
			cat | gpg -e -r "$ID" -o "$passfile" --yes
		elif [[ $noecho -eq 1 ]]; then
			while true; do
				stty -echo
				echo -n "Enter password for $path: "
				read password
				echo
				echo -n "Retype password for $path: "
				read password_again
				echo
				stty echo
				if [[ $password == $password_again ]]; then
					gpg -q -e -r "$ID" -o "$passfile" --yes <<<"$password"
					break
				else
					echo "Error: the entered passwords do not match."
				fi
			done
		else
			echo -n "Enter password for $path: "
			head -n 1 | gpg -q -e -r "$ID" -o "$passfile" --yes
		fi
		if [[ -d $GIT ]]; then
			git add "$passfile"
			git commit -m "Added given password for $path to store."
		fi
		;;
	edit)
		if [[ $# -ne 1 ]]; then
			echo "Usage $program $command pass-name"
			exit 1
		fi

		path="$1"
		mkdir -p -v "$PREFIX/$(dirname "$path")"
		passfile="$PREFIX/$path.gpg"
		template="$program.XXXXXXXXXXXXX"

		if [ -d /dev/shm -a -w /dev/shm -a -x /dev/shm ]; then
			tmp_dir="$(TMPDIR=/dev/shm mktemp -t $template -d)"
		else
			echo    "Your system does not have /dev/shm, which means that it may"
			echo    "be difficult to entirely erase the temporary non-encrypted"
			echo    "password file after editing. Are you sure you would like to"
			echo -n "continue? [y/N] "
			read yesno
			if ! [[ $yesno == "y" || $yesno == "Y" ]]; then
				exit 1
			fi
			tmp_dir="$(mktemp -t $template -d)"
		fi
		tmp_file="$(TMPDIR="$tmp_dir" mktemp -t $template)"

		action="Added"
		if [[ -f $passfile ]]; then
			if ! gpg -q -d -o "$tmp_file" --yes "$passfile";  then
				rm -rf "$tmp_file" "$tmp_dir"
				exit 1
			fi
			action="Edited"
		fi
		${EDITOR:-vi} "$tmp_file"
		while ! gpg -q -e -r "$ID" -o "$passfile" --yes "$tmp_file"; do
			echo "GPG encryption failed. Retrying."
			sleep 1
		done
		rm -rf "$tmp_file" "$tmp_dir"

		if [[ -d $GIT ]]; then
			git add "$passfile"
			git commit -m "$action password for $path using ${EDITOR:-vi}."
		fi
		;;
	generate)
		clip=0
		symbols="-y"

		opts="$(getopt -o nc -l no-symbols,clip -n $program -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-n|--no-symbols) symbols=""; shift ;;
			-c|--clip) clip=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || $# -ne 2 ]]; then
			echo "Usage: $program $command [--no-symbols,-n] [--clip,-c] pass-name pass-length"
			exit 1
		fi
		path="$1"
		length="$2"
		if ! [[ $length =~ ^[0-9]+$ ]]; then
			echo "pass-length \"$length\" must be a number."
			exit 1
		fi
		mkdir -p -v "$PREFIX/$(dirname "$path")"
		pass="$(pwgen -s $symbols $length 1)"
		passfile="$PREFIX/$path.gpg"
		gpg -q -e -r "$ID" -o "$passfile" --yes <<<"$pass"
		if [[ -d $GIT ]]; then
			git add "$passfile"
			git commit -m "Added generated password for $path to store."
		fi
		
		if [ $clip -eq 0 ]; then
			echo "The generated password to $path is:"
			echo "$pass"
		else
			clip "$pass" "$path"
		fi
		;;
	delete|rm|remove)
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command pass-name"
			exit
		fi
		path="$1"
		passfile="$PREFIX/$path.gpg"
		if ! [[ -f $passfile ]]; then
			echo "$path is not in the password store."
			exit 1
		fi
		rm -i -v "$passfile"
		if [[ -d $GIT ]] && ! [[ -f $passfile ]]; then
			git rm -f "$passfile"
			git commit -m "Removed $path from store."
		fi
		;;
	push|pull)
		if [[ -d $GIT ]]; then
			exec git $command "$@"
		else
			echo "Error: the password store is not a git repository."
			exit 1
		fi
		;;
	git)
		if [[ $1 == "init" ]] || [[ -d $GIT ]]; then
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

#!/bin/bash

umask 077

PREFIX="$HOME/.password-store"
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
    $program insert [--multiline,-m] pass-name
        Insert new optionally multiline password.
    $program generate [--no-symbols,-n] [--clip,-c] pass-name pass-length
        Generate a new password of pass-length with optionally no symbols.
        Optionally put it on the clipboard and clear board after 45 seconds.
    $program remove pass-name
        Remove existing password.
    $program push
        If the password store is a git repository, push the latest changes.
    $program pull
        If the password store is a git repository, pull the latest changes.
    $program help
        Show this text.
_EOF
}
isCommand() {
	case "$1" in
		init|ls|show|insert|generate|remove|push|pull|help) return 0 ;;
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
		sleep 45s
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

program="$0"
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
		echo "gpg_id" > "$ID"
		echo "Password store initialized for gpg_id."
		exit 0
		;;
	help)
		usage
		exit 0
		;;
esac

if ! [[ -f $ID ]]; then
	echo "You must run:"
	echo "    $0 init your-gpg-id"
	echo "before you may use the password store."
	echo
	usage
	exit 1
else
	ID="$(head -n 1 "$ID")"
fi

case "$command" in
	show|ls)
		clip=0
		if [[ $1 == "--clip" || $1 == "-c" ]]; then
			clip=1
			shift
		fi
		path="$1"
		if [[ -d $PREFIX/$path ]]; then
			if [[ $path == "" ]]; then
				echo "Password Store"
			else
				echo $path
			fi
			tree "$PREFIX/$path" | tail -n +2 | head -n -2 | sed 's/\(.*\)\.gpg$/\1/';
		else
			passfile="$PREFIX/$path.gpg"
			if ! [[ -f $passfile ]]; then
				echo "$path is not in the password store."
				exit 1
			fi
			if [ $clip -eq 0 ]; then
				exec gpg -q -d "$passfile"
			else
				clip $(gpg -q -d "$passfile") $path
			fi
		fi
		;;
	insert)
		ml=0
		if [[ $1 == "--multiline" || $1 == "-m" ]]; then
			ml=1
			shift
		fi
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command [--multiline,-m] pass-name"
			exit 1
		fi
		path="$1"
		mkdir -p -v "$PREFIX/$(dirname "$path")"

		passfile="$PREFIX/$path.gpg"
		if [[ $ml -eq 0 ]]; then
			echo -n "Enter password for $path: "
			head -n 1 | gpg -e -r "$ID" > "$passfile"
		else
			echo "Enter contents of $path and press Ctrl+D when finished:"
			echo
			cat | gpg -e -r "$ID" > "$passfile"
		fi
		if [[ -d $GIT ]]; then
			git add "$passfile"
			git commit -m "Added given password for $path to store."
		fi
		;;
	generate)
		clip=0
		symbols="-y"
		while true; do
			if [[ $1 == "--no-symbols" || $1 == "-n" ]]; then
				symbols=""
				shift
			elif [[ $1 == "--clip" || $1 == "-c" ]]; then
				clip=1
				shift
			else
				break
			fi
		done
		if [[ $# -ne 2 ]]; then
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
		echo $pass | gpg -e -r "$ID" > "$passfile"
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
	remove)
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
			exec git $command $@
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

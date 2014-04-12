#!/bin/bash

# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

umask "${PASSWORD_STORE_UMASK:-077}"
set -o pipefail

GPG_OPTS="--quiet --yes --compress-algo=none"
GPG="gpg"
which gpg2 &>/dev/null && GPG="gpg2"
[[ -n $GPG_AGENT_INFO || $GPG == "gpg2" ]] && GPG_OPTS="$GPG_OPTS --batch --use-agent"

PREFIX="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
X_SELECTION="${PASSWORD_STORE_X_SELECTION:-clipboard}"
CLIP_TIME="${PASSWORD_STORE_CLIP_TIME:-45}"

export GIT_DIR="${PASSWORD_STORE_GIT:-$PREFIX}/.git"
export GIT_WORK_TREE="${PASSWORD_STORE_GIT:-$PREFIX}"


version() {
	cat <<-_EOF
	============================================
	= pass: the standard unix password manager =
	=                                          =
	=                   v1.5                   =
	=                                          =
	=             Jason A. Donenfeld           =
	=               Jason@zx2c4.com            =
	=                                          =
	= http://zx2c4.com/projects/password-store =
	============================================
	_EOF
}
usage() {
	version
	echo
	cat <<-_EOF
	Usage:
	    $program init [--reencrypt,-e] [--path=subfolder,-p subfolder] gpg-id...
		Initialize new password storage and use gpg-id for encryption.
		Optionally reencrypt existing passwords using new gpg-id.
	    $program [ls] [subfolder]
		List passwords.
	    $program [show] [--clip,-c] pass-name
		Show existing password and optionally put it on the clipboard.
		If put on the clipboard, it will be cleared in $CLIP_TIME seconds.
	    $program insert [--echo,-e | --multiline,-m] [--force,-f] pass-name
		Insert new password. Optionally, echo the password back to the console
		during entry. Or, optionally, the entry may be multiline. Prompt before
		overwriting existing password unless forced.
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
	[[ $(git config --bool --get pass.signcommits) == "true" ]] && sign="-S" || sign=""
	git commit $sign -m "$2"
}
yesno() {
	read -r -p "$1 [y/N] " response
	[[ $response == [yY] ]] || exit 1
}
set_gpg_recipients() {
	gpg_recipient_args=( )

	if [[ -n $PASSWORD_STORE_KEY ]]; then
		for gpg_id in $PASSWORD_STORE_KEY; do
			gpg_recipient_args+=( "-r" "$gpg_id" )
		done
		return
	fi

	local current="$PREFIX/$1"
	while [[ $current != "$PREFIX" && ! -f $current/.gpg-id ]]; do
		current="${current%/*}"
	done
	current="$current/.gpg-id"

	if [[ ! -f $current ]]; then
		cat <<-_EOF
		ERROR: You must run:
		    $program init your-gpg-id
		before you may use the password store.

		_EOF
		usage
		exit 1
	fi

	while read -r gpg_id; do
		gpg_recipient_args+=( "-r" "$gpg_id" )
	done < "$current"
}

#
# BEGIN Platform definable
#
clip() {
	# This base64 business is a disgusting hack to deal with newline inconsistancies
	# in shell. There must be a better way to deal with this, but because I'm a dolt,
	# we're going with this for now.

	sleep_argv0="password store sleep on display $DISPLAY"
	pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
	before="$(xclip -o -selection "$X_SELECTION" | base64)"
	echo -n "$1" | xclip -selection "$X_SELECTION"
	(
		( exec -a "$sleep_argv0" sleep "$CLIP_TIME" )
		now="$(xclip -o -selection "$X_SELECTION" | base64)"
		[[ $now != $(echo -n "$1" | base64) ]] && before="$now"

		# It might be nice to programatically check to see if klipper exists,
		# as well as checking for other common clipboard managers. But for now,
		# this works fine -- if qdbus isn't there or if klipper isn't running,
		# this essentially becomes a no-op.
		#
		# Clipboard managers frequently write their history out in plaintext,
		# so we axe it here:
		qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null

		echo "$before" | base64 -d | xclip -selection "$X_SELECTION"
	) 2>/dev/null & disown
	echo "Copied $2 to clipboard. Will clear in $CLIP_TIME seconds."
}
tmpdir() {
	if [[ -d /dev/shm && -w /dev/shm && -x /dev/shm ]]; then
		tmp_dir="$(TMPDIR=/dev/shm mktemp -d -t "$template")"
	else
		yesno "$(echo    "Your system does not have /dev/shm, which means that it may"
		         echo    "be difficult to entirely erase the temporary non-encrypted"
		         echo    "password file after editing. Are you sure you would like to"
		         echo -n "continue?")"
		tmp_dir="$(mktemp -d -t "$template")"
	fi

}
GETOPT="getopt"
SHRED="shred -f -z"

# source /path/to/platform-defined-functions
#
# END Platform definable
#

program="${0##*/}"
command="$1"
if is_command "$command"; then
	shift
else
	command="show"
fi

case "$command" in
	init)
		reencrypt=0
		id_path=""

		opts="$($GETOPT -o ep: -l reencrypt,path: -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-e|--reencrypt) reencrypt=1; shift ;;
			-p|--path) id_path="$2"; shift 2 ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || $# -lt 1 ]]; then
			echo "Usage: $program $command [--reencrypt,-e] [--path=subfolder,-p subfolder] gpg-id..."
			exit 1
		fi
		if [[ -n $id_path && ! -d $PREFIX/$id_path ]]; then
			if [[ -e $PREFIX/$id_path ]]; then
				echo "Error: $PREFIX/$id_path exists but is not a directory."
				exit 1;
			fi
		fi

		mkdir -v -p "$PREFIX/$id_path"
		gpg_id="$PREFIX/$id_path/.gpg-id"
		printf "%s\n" "$@" > "$gpg_id"
		id_print="$(printf "%s, " "$@")"
		echo "Password store initialized for ${id_print%, }"
		git_add_file "$gpg_id" "Set GPG id to ${id_print%, }."

		if [[ $reencrypt -eq 1 ]]; then
			find "$PREFIX/$id_path" -iname '*.gpg' | while read -r passfile; do
				fake_uniqueness_safety="$RANDOM"
				passfile_dir=${passfile%/*}
				passfile_dir=${passfile_dir#$PREFIX}
				passfile_dir=${passfile_dir#/}
				set_gpg_recipients "$passfile_dir"
				$GPG -d $GPG_OPTS "$passfile" | $GPG -e "${gpg_recipient_args[@]}" -o "$passfile.new.$fake_uniqueness_safety" $GPG_OPTS &&
				mv -v "$passfile.new.$fake_uniqueness_safety" "$passfile"
			done
			git_add_file "$PREFIX/$id_path" "Reencrypted password store using new GPG id ${id_print}."
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
		passfile="$PREFIX/$path.gpg"
		if [[ -f $passfile ]]; then
			if [[ $clip -eq 0 ]]; then
				exec $GPG -d $GPG_OPTS "$passfile"
			else
				pass="$($GPG -d $GPG_OPTS "$passfile" | head -n 1)"
				[[ -n $pass ]] || exit 1
				clip "$pass" "$path"
			fi
		elif [[ -d $PREFIX/$path ]]; then
			if [[ -z $path ]]; then
				echo "Password Store"
			else
				echo "${path%\/}"
			fi
			tree -l --noreport "$PREFIX/$path" | tail -n +2 | sed 's/\.gpg$//'
		else
			echo "$path is not in the password store."
			exit 1
		fi
		;;
	insert)
		multiline=0
		noecho=1
		force=0

		opts="$($GETOPT -o mef -l multiline,echo,force -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-m|--multiline) multiline=1; shift ;;
			-e|--echo) noecho=0; shift ;;
			-f|--force) force=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || ( $multiline -eq 1 && $noecho -eq 0 ) || $# -ne 1 ]]; then
			echo "Usage: $program $command [--echo,-e | --multiline,-m] [--force,-f] pass-name"
			exit 1
		fi
		path="$1"
		passfile="$PREFIX/$path.gpg"

		[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

		mkdir -p -v "$PREFIX/$(dirname "$path")"
		set_gpg_recipients "$(dirname "$path")"

		if [[ $multiline -eq 1 ]]; then
			echo "Enter contents of $path and press Ctrl+D when finished:"
			echo
			$GPG -e "${gpg_recipient_args[@]}" -o "$passfile" $GPG_OPTS
		elif [[ $noecho -eq 1 ]]; then
			while true; do
				read -r -p "Enter password for $path: " -s password
				echo
				read -r -p "Retype password for $path: " -s password_again
				echo
				if [[ $password == "$password_again" ]]; then
					$GPG -e "${gpg_recipient_args[@]}" -o "$passfile" $GPG_OPTS <<<"$password"
					break
				else
					echo "Error: the entered passwords do not match."
				fi
			done
		else
			read -r -p "Enter password for $path: " -e password
			$GPG -e "${gpg_recipient_args[@]}" -o "$passfile" $GPG_OPTS <<<"$password"
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
		set_gpg_recipients "$(dirname "$path")"
		passfile="$PREFIX/$path.gpg"
		template="$program.XXXXXXXXXXXXX"

		trap '$SHRED "$tmp_file"; rm -rf "$tmp_dir" "$tmp_file"' INT TERM EXIT

		tmpdir #Defines $tmp_dir
		tmp_file="$(TMPDIR="$tmp_dir" mktemp -t "$template")"

		action="Added"
		if [[ -f $passfile ]]; then
			$GPG -d -o "$tmp_file" $GPG_OPTS "$passfile" || exit 1
			action="Edited"
		fi
		${EDITOR:-vi} "$tmp_file"
		while ! $GPG -e "${gpg_recipient_args[@]}" -o "$passfile" $GPG_OPTS "$tmp_file"; do
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
		set_gpg_recipients "$(dirname "$path")"
		passfile="$PREFIX/$path.gpg"

		[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

		pass="$(pwgen -s $symbols $length 1)"
		[[ -n $pass ]] || exit 1
		$GPG -e "${gpg_recipient_args[@]}" -o "$passfile" $GPG_OPTS <<<"$pass"
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

#!/usr/bin/env bash

# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

umask "${PASSWORD_STORE_UMASK:-077}"
set -o pipefail

GPG_OPTS=( "--quiet" "--yes" "--compress-algo=none" )
GPG="gpg"
which gpg2 &>/dev/null && GPG="gpg2"
[[ -n $GPG_AGENT_INFO || $GPG == "gpg2" ]] && GPG_OPTS+=( "--batch" "--use-agent" )

PREFIX="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
X_SELECTION="${PASSWORD_STORE_X_SELECTION:-clipboard}"
CLIP_TIME="${PASSWORD_STORE_CLIP_TIME:-45}"

export GIT_DIR="${PASSWORD_STORE_GIT:-$PREFIX}/.git"
export GIT_WORK_TREE="${PASSWORD_STORE_GIT:-$PREFIX}"

#
# BEGIN helper functions
#

git_add_file() {
	[[ -d $GIT_DIR ]] || return
	git add "$1" || return
	[[ -n $(git status --porcelain "$1") ]] || return
	git_commit "$2"
}
git_commit() {
	local sign=""
	[[ -d $GIT_DIR ]] || return
	[[ $(git config --bool --get pass.signcommits) == "true" ]] && sign="-S"
	git commit $sign -m "$1"
}
yesno() {
	[[ -t 0 ]] || return 0
	local response
	read -r -p "$1 [y/N] " response
	[[ $response == [yY] ]] || exit 1
}
die() {
	echo "$@" >&2
	exit 1
}
set_gpg_recipients() {
	GPG_RECIPIENT_ARGS=( )
	GPG_RECIPIENTS=( )

	if [[ -n $PASSWORD_STORE_KEY ]]; then
		for gpg_id in $PASSWORD_STORE_KEY; do
			GPG_RECIPIENT_ARGS+=( "-r" "$gpg_id" )
			GPG_RECIPIENTS+=( "$gpg_id" )
		done
		return
	fi

	local current="$PREFIX/$1"
	while [[ $current != "$PREFIX" && ! -f $current/.gpg-id ]]; do
		current="${current%/*}"
	done
	current="$current/.gpg-id"

	if [[ ! -f $current ]]; then
		cat >&2 <<-_EOF
		Error: You must run:
		    $PROGRAM init your-gpg-id
		before you may use the password store.

		_EOF
		cmd_usage
		exit 1
	fi

	local gpg_id
	while read -r gpg_id; do
		GPG_RECIPIENT_ARGS+=( "-r" "$gpg_id" )
		GPG_RECIPIENTS+=( "$gpg_id" )
	done < "$current"
}
agent_check() {
	[[ ! -t 0 || -n $GPG_AGENT_INFO ]] || yesno "$(cat <<-_EOF
	You are not running gpg-agent. This means that you will
	need to enter your password for each and every gpg file
	that pass processes. This could be quite tedious.

	Are you sure you would like to continue without gpg-agent?
	_EOF
	)"
}
reencrypt_path() {
	local prev_gpg_recipients="" gpg_keys="" current_keys="" index passfile
	local groups="$($GPG --list-config --with-colons | grep "^cfg:group:.*")"
	while read -r -d "" passfile; do
		local passfile_dir="${passfile%/*}"
		passfile_dir="${passfile_dir#$PREFIX}"
		passfile_dir="${passfile_dir#/}"
		local passfile_display="${passfile#$PREFIX/}"
		passfile_display="${passfile_display%.gpg}"
		local passfile_temp="${passfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"

		set_gpg_recipients "$passfile_dir"
		if [[ $prev_gpg_recipients != "${GPG_RECIPIENTS[*]}" ]]; then
			for index in "${!GPG_RECIPIENTS[@]}"; do
				local group="$(sed -n "s/^cfg:group:$(sed 's/[\/&]/\\&/g' <<<"${GPG_RECIPIENTS[$index]}"):\\(.*\\)\$/\\1/p" <<<"$groups" | head -n 1)"
				[[ -z $group ]] && continue
				IFS=";" eval 'GPG_RECIPIENTS+=( $group )' # http://unix.stackexchange.com/a/92190
				unset GPG_RECIPIENTS[$index]
			done
			gpg_keys="$($GPG --list-keys --keyid-format long "${GPG_RECIPIENTS[@]}" | sed -n 's/sub *.*\/\([A-F0-9]\{16\}\) .*/\1/p' | LC_ALL=C sort -u)"
		fi
		current_keys="$($GPG -v --no-secmem-warning --no-permission-warning --list-only --keyid-format long "$passfile" 2>&1 | cut -d ' ' -f 5 | LC_ALL=C sort -u)"

		if [[ $gpg_keys != "$current_keys" ]]; then
			echo "$passfile_display: reencrypting to ${gpg_keys//$'\n'/ }"
			$GPG -d "${GPG_OPTS[@]}" "$passfile" | $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile_temp" "${GPG_OPTS[@]}" &&
			mv "$passfile_temp" "$passfile" || rm -f "$passfile_temp"
		fi
		prev_gpg_recipients="${GPG_RECIPIENTS[*]}"
	done < <(find "$1" -iname '*.gpg' -print0)
}
check_sneaky_paths() {
	local path
	for path in "$@"; do
		[[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] && die "Error: You've attempted to pass a sneaky path to pass. Go home."
	done
}

#
# END helper functions
#

#
# BEGIN platform definable
#

clip() {
	# This base64 business is because bash cannot store binary data in a shell
	# variable. Specifically, it cannot store nulls nor (non-trivally) store
	# trailing new lines.

	local sleep_argv0="password store sleep on display $DISPLAY"
	pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
	local before="$(xclip -o -selection "$X_SELECTION" | base64)"
	echo -n "$1" | xclip -selection "$X_SELECTION"
	(
		( exec -a "$sleep_argv0" sleep "$CLIP_TIME" )
		local now="$(xclip -o -selection "$X_SELECTION" | base64)"
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
	[[ -n $SECURE_TMPDIR ]] && return
	local warn=1
	[[ $1 == "nowarn" ]] && warn=0
	local template="$PROGRAM.XXXXXXXXXXXXX"
	if [[ -d /dev/shm && -w /dev/shm && -x /dev/shm ]]; then
		SECURE_TMPDIR="$(mktemp -d "/dev/shm/$template")"
		remove_tmpfile() {
			rm -rf "$SECURE_TMPDIR"
		}
		trap remove_tmpfile INT TERM EXIT
	else
		[[ $warn -eq 1 ]] && yesno "$(cat <<-_EOF
		Your system does not have /dev/shm, which means that it may
		be difficult to entirely erase the temporary non-encrypted
		password file after editing.

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
GETOPT="getopt"
SHRED="shred -f -z"

source "$(dirname "$0")/platform/$(uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh" 2>/dev/null # PLATFORM_FUNCTION_FILE

#
# END platform definable
#


#
# BEGIN subcommand functions
#

cmd_version() {
	cat <<-_EOF
	============================================
	= pass: the standard unix password manager =
	=                                          =
	=                  v1.6.3                  =
	=                                          =
	=             Jason A. Donenfeld           =
	=               Jason@zx2c4.com            =
	=                                          =
	=      http://www.passwordstore.org/       =
	============================================
	_EOF
}

cmd_usage() {
	cmd_version
	echo
	cat <<-_EOF
	Usage:
	    $PROGRAM init [--path=subfolder,-p subfolder] gpg-id...
	        Initialize new password storage and use gpg-id for encryption.
	        Selectively reencrypt existing passwords using new gpg-id.
	    $PROGRAM [ls] [subfolder]
	        List passwords.
	    $PROGRAM find pass-names...
	    	List passwords that match pass-names.
	    $PROGRAM [show] [--clip,-c] pass-name
	        Show existing password and optionally put it on the clipboard.
	        If put on the clipboard, it will be cleared in $CLIP_TIME seconds.
	    $PROGRAM grep search-string
	        Search for password files containing search-string when decrypted.
	    $PROGRAM insert [--echo,-e | --multiline,-m] [--force,-f] pass-name
	        Insert new password. Optionally, echo the password back to the console
	        during entry. Or, optionally, the entry may be multiline. Prompt before
	        overwriting existing password unless forced.
	    $PROGRAM edit pass-name
	        Insert a new password or edit an existing password using ${EDITOR:-vi}.
	    $PROGRAM generate [--no-symbols,-n] [--clip,-c] [--in-place,-i | --force,-f] pass-name pass-length
	        Generate a new password of pass-length with optionally no symbols.
	        Optionally put it on the clipboard and clear board after 45 seconds.
	        Prompt before overwriting existing password unless forced.
	        Optionally replace only the first line of an existing file with a new password.
	    $PROGRAM rm [--recursive,-r] [--force,-f] pass-name
	        Remove existing password or directory, optionally forcefully.
	    $PROGRAM mv [--force,-f] old-path new-path
	        Renames or moves old-path to new-path, optionally forcefully, selectively reencrypting.
	    $PROGRAM cp [--force,-f] old-path new-path
	        Copies old-path to new-path, optionally forcefully, selectively reencrypting.
	    $PROGRAM git git-command-args...
	        If the password store is a git repository, execute a git command
	        specified by git-command-args.
	    $PROGRAM help
	        Show this text.
	    $PROGRAM version
	        Show version information.

	More information may be found in the pass(1) man page.
	_EOF
}

cmd_init() {
	local opts id_path=""
	opts="$($GETOPT -o p: -l path: -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-p|--path) id_path="$2"; shift 2 ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || $# -lt 1 ]] && die "Usage: $PROGRAM $COMMAND [--path=subfolder,-p subfolder] gpg-id..."
	[[ -n $id_path ]] && check_sneaky_paths "$id_path"
	[[ -n $id_path && ! -d $PREFIX/$id_path && -e $PREFIX/$id_path ]] && die "Error: $PREFIX/$id_path exists but is not a directory."

	local gpg_id="$PREFIX/$id_path/.gpg-id"

	if [[ $# -eq 1 && -z $1 ]]; then
		[[ ! -f "$gpg_id" ]] && die "Error: $gpg_id does not exist and so cannot be removed."
		rm -v -f "$gpg_id" || exit 1
		if [[ -d $GIT_DIR ]]; then
			git rm -qr "$gpg_id"
			git_commit "Deinitialize ${gpg_id}."
		fi
		rmdir -p "${gpg_id%/*}" 2>/dev/null
	else
		mkdir -v -p "$PREFIX/$id_path"
		printf "%s\n" "$@" > "$gpg_id"
		local id_print="$(printf "%s, " "$@")"
		echo "Password store initialized for ${id_print%, }"
		git_add_file "$gpg_id" "Set GPG id to ${id_print%, }."
	fi

	agent_check
	reencrypt_path "$PREFIX/$id_path"
	git_add_file "$PREFIX/$id_path" "Reencrypt password store using new GPG id ${id_print%, }."
}

cmd_show() {
	local opts clip=0
	opts="$($GETOPT -o c -l clip -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-c|--clip) clip=1; shift ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 ]] && die "Usage: $PROGRAM $COMMAND [--clip,-c] [pass-name]"

	local path="$1"
	local passfile="$PREFIX/$path.gpg"
	check_sneaky_paths "$path"
	if [[ -f $passfile ]]; then
		if [[ $clip -eq 0 ]]; then
			exec $GPG -d "${GPG_OPTS[@]}" "$passfile"
		else
			local pass="$($GPG -d "${GPG_OPTS[@]}" "$passfile" | head -n 1)"
			[[ -n $pass ]] || exit 1
			clip "$pass" "$path"
		fi
	elif [[ -d $PREFIX/$path ]]; then
		if [[ -z $path ]]; then
			echo "Password Store"
		else
			echo "${path%\/}"
		fi
		tree -C -l --noreport "$PREFIX/$path" | tail -n +2 | sed 's/\.gpg$//'
	elif [[ -z $path ]]; then
		die "Error: password store is empty. Try \"pass init\"."
	else
		die "Error: $path is not in the password store."
	fi
}

cmd_find() {
	[[ -z "$@" ]] && die "Usage: $PROGRAM $COMMAND pass-names..."
	IFS="," eval 'echo "Search Terms: $*"'
	local terms="*$(printf '%s*|*' "$@")"
	tree -C -l --noreport -P "${terms%|*}" --prune --matchdirs --ignore-case "$PREFIX" | tail -n +2 | sed 's/\.gpg$//'
}

cmd_grep() {
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND search-string"
	agent_check
	local search="$1" passfile grepresults
	while read -r -d "" passfile; do
		grepresults="$($GPG -d "${GPG_OPTS[@]}" "$passfile" | grep --color=always "$search")"
		[ $? -ne 0 ] && continue
		passfile="${passfile%.gpg}"
		passfile="${passfile#$PREFIX/}"
		local passfile_dir="${passfile%/*}"
		passfile="${passfile##*/}"
		printf "\e[94m%s/\e[1m%s\e[0m:\n" "$passfile_dir" "$passfile"
		echo "$grepresults"
	done < <(find "$PREFIX" -iname '*.gpg' -print0)
}

cmd_insert() {
	local opts multiline=0 noecho=1 force=0
	opts="$($GETOPT -o mef -l multiline,echo,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-m|--multiline) multiline=1; shift ;;
		-e|--echo) noecho=0; shift ;;
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || ( $multiline -eq 1 && $noecho -eq 0 ) || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--echo,-e | --multiline,-m] [--force,-f] pass-name"
	local path="$1"
	local passfile="$PREFIX/$path.gpg"
	check_sneaky_paths "$path"

	[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

	mkdir -p -v "$PREFIX/$(dirname "$path")"
	set_gpg_recipients "$(dirname "$path")"

	if [[ $multiline -eq 1 ]]; then
		echo "Enter contents of $path and press Ctrl+D when finished:"
		echo
		$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}"
	elif [[ $noecho -eq 1 ]]; then
		local password password_again
		while true; do
			read -r -p "Enter password for $path: " -s password || exit 1
			echo
			read -r -p "Retype password for $path: " -s password_again || exit 1
			echo
			if [[ $password == "$password_again" ]]; then
				$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$password"
				break
			else
				echo "Error: the entered passwords do not match."
			fi
		done
	else
		local password
		read -r -p "Enter password for $path: " -e password
		$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$password"
	fi
	git_add_file "$passfile" "Add given password for $path to store."
}

cmd_edit() {
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND pass-name"

	local path="$1"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname "$path")"
	set_gpg_recipients "$(dirname "$path")"
	local passfile="$PREFIX/$path.gpg"

	tmpdir #Defines $SECURE_TMPDIR
	local tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXX")-${path//\//-}.txt"


	local action="Add"
	if [[ -f $passfile ]]; then
		$GPG -d -o "$tmp_file" "${GPG_OPTS[@]}" "$passfile" || exit 1
		action="Edit"
	fi
	${EDITOR:-vi} "$tmp_file"
	[[ -f $tmp_file ]] || die "New password not saved."
	while ! $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" "$tmp_file"; do
		yesno "GPG encryption failed. Would you like to try again?"
	done
	git_add_file "$passfile" "$action password for $path using ${EDITOR:-vi}."
}

cmd_generate() {
	local opts clip=0 force=0 symbols="-y" inplace=0
	opts="$($GETOPT -o ncif -l no-symbols,clip,in-place,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-n|--no-symbols) symbols=""; shift ;;
		-c|--clip) clip=1; shift ;;
		-f|--force) force=1; shift ;;
		-i|--in-place) inplace=1; shift ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || $# -ne 2 || ( $force -eq 1 && $inplace -eq 1 ) ]] && die "Usage: $PROGRAM $COMMAND [--no-symbols,-n] [--clip,-c] [--in-place,-i | --force,-f] pass-name pass-length"
	local path="$1"
	local length="$2"
	check_sneaky_paths "$path"
	[[ ! $length =~ ^[0-9]+$ ]] && die "Error: pass-length \"$length\" must be a number."
	mkdir -p -v "$PREFIX/$(dirname "$path")"
	set_gpg_recipients "$(dirname "$path")"
	local passfile="$PREFIX/$path.gpg"

	[[ $inplace -eq 0 && $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

	local pass="$(pwgen -s $symbols $length 1)"
	[[ -n $pass ]] || exit 1
	if [[ $inplace -eq 0 ]]; then
		$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$pass"
	else
		local passfile_temp="${passfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"
		if $GPG -d "${GPG_OPTS[@]}" "$passfile" | sed $'1c \\\n'"$(sed 's/[\/&]/\\&/g' <<<"$pass")"$'\n' | $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile_temp" "${GPG_OPTS[@]}"; then
			mv "$passfile_temp" "$passfile"
		else
			rm -f "$passfile_temp"
			die "Could not reencrypt new password."
		fi
	fi
	local verb="Add"
	[[ $inplace -eq 1 ]] && verb="Replace"
	git_add_file "$passfile" "$verb generated password for ${path}."

	if [[ $clip -eq 0 ]]; then
		printf "\e[1m\e[37mThe generated password for \e[4m%s\e[24m is:\e[0m\n\e[1m\e[93m%s\e[0m\n" "$path" "$pass"
	else
		clip "$pass" "$path"
	fi
}

cmd_delete() {
	local opts recursive="" force=0
	opts="$($GETOPT -o rf -l recursive,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-r|--recursive) recursive="-r"; shift ;;
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--recursive,-r] [--force,-f] pass-name"
	local path="$1"
	check_sneaky_paths "$path"

	local passfile="$PREFIX/${path%/}"
	if [[ ! -d $passfile ]]; then
		passfile="$PREFIX/$path.gpg"
		[[ ! -f $passfile ]] && die "Error: $path is not in the password store."
	fi

	[[ $force -eq 1 ]] || yesno "Are you sure you would like to delete $path?"

	rm $recursive -f -v "$passfile"
	if [[ -d $GIT_DIR && ! -e $passfile ]]; then
		git rm -qr "$passfile"
		git_commit "Remove $path from store."
	fi
	rmdir -p "${passfile%/*}" 2>/dev/null
}

cmd_copy_move() {
	local opts move=1 force=0
	[[ $1 == "copy" ]] && move=0
	shift
	opts="$($GETOPT -o f -l force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done
	[[ $# -ne 2 ]] && die "Usage: $PROGRAM $COMMAND [--force,-f] old-path new-path"
	check_sneaky_paths "$@"
	local old_path="$PREFIX/${1%/}"
	local new_path="$PREFIX/$2"
	local old_dir="$old_path"

	if [[ ! -d $old_path ]]; then
		old_dir="${old_path%/*}"
		old_path="${old_path}.gpg"
		[[ ! -f $old_path ]] && die "Error: $1 is not in the password store."
	fi

	mkdir -p -v "${new_path%/*}"
	[[ -d $old_path || -d $new_path || $new_path =~ /$ ]] || new_path="${new_path}.gpg"

	local interactive="-i"
	[[ ! -t 0 || $force -eq 1 ]] && interactive="-f"

	if [[ $move -eq 1 ]]; then
		mv $interactive -v "$old_path" "$new_path" || exit 1
		[[ -e "$new_path" ]] && reencrypt_path "$new_path"

		if [[ -d $GIT_DIR && ! -e $old_path ]]; then
			git rm -qr "$old_path"
			git_add_file "$new_path" "Rename ${1} to ${2}."
		fi
		rmdir -p "$old_dir" 2>/dev/null
	else
		cp $interactive -r -v "$old_path" "$new_path" || exit 1
		[[ -e "$new_path" ]] && reencrypt_path "$new_path"
		git_add_file "$new_path" "Copy ${1} to ${2}."
	fi
}

cmd_git() {
	if [[ $1 == "init" ]]; then
		git "$@" || exit 1
		git_add_file "$PREFIX" "Add current contents of password store."

		echo '*.gpg diff=gpg' > "$PREFIX/.gitattributes"
		git_add_file .gitattributes "Configure git repository for gpg file diff."
		git config --local diff.gpg.binary true
		git config --local diff.gpg.textconv "$GPG -d ${GPG_OPTS[*]}"
	elif [[ -d $GIT_DIR ]]; then
		tmpdir nowarn #Defines $SECURE_TMPDIR. We don't warn, because at most, this only copies encrypted files.
		export TMPDIR="$SECURE_TMPDIR"
		git "$@"
	else
		die "Error: the password store is not a git repository. Try \"$PROGRAM git init\"."
	fi
}

#
# END subcommand functions
#

PROGRAM="${0##*/}"
COMMAND="$1"

case "$1" in
	init) shift;			cmd_init "$@" ;;
	help|--help) shift;		cmd_usage "$@" ;;
	version|--version) shift;	cmd_version "$@" ;;
	show|ls|list) shift;		cmd_show "$@" ;;
	find|search) shift;		cmd_find "$@" ;;
	grep) shift;			cmd_grep "$@" ;;
	insert) shift;			cmd_insert "$@" ;;
	edit) shift;			cmd_edit "$@" ;;
	generate) shift;		cmd_generate "$@" ;;
	delete|rm|remove) shift;	cmd_delete "$@" ;;
	rename|mv) shift;		cmd_copy_move "move" "$@" ;;
	copy|cp) shift;			cmd_copy_move "copy" "$@" ;;
	git) shift;			cmd_git "$@" ;;
	*) COMMAND="show";		cmd_show "$@" ;;
esac
exit 0

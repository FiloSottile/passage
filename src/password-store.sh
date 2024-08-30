#!/usr/bin/env bash

# Copyright (C) 2012 - 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

umask "${PASSWORD_STORE_UMASK:-077}"
set -o pipefail

AGE="${PASSAGE_AGE:-age}"
PASSAGE="1"

PREFIX="${PASSAGE_DIR:-$HOME/.passage/store}"
IDENTITIES_FILE="${PASSAGE_IDENTITIES_FILE:-$HOME/.passage/identities}"
EXTENSIONS="${PASSAGE_EXTENSIONS_DIR:-$HOME/.passage/extensions}"
X_SELECTION="${PASSWORD_STORE_X_SELECTION:-clipboard}"
CLIP_TIME="${PASSWORD_STORE_CLIP_TIME:-45}"
GENERATED_LENGTH="${PASSWORD_STORE_GENERATED_LENGTH:-25}"
CHARACTER_SET="${PASSWORD_STORE_CHARACTER_SET:-[:punct:][:alnum:]}"
CHARACTER_SET_NO_SYMBOLS="${PASSWORD_STORE_CHARACTER_SET_NO_SYMBOLS:-[:alnum:]}"

unset GIT_DIR GIT_WORK_TREE GIT_NAMESPACE GIT_INDEX_FILE GIT_INDEX_VERSION GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
export GIT_CEILING_DIRECTORIES="$PREFIX/.."

#
# BEGIN helper functions
#

set_git() {
	INNER_GIT_DIR="${1%/*}"
	while [[ ! -d $INNER_GIT_DIR && ${INNER_GIT_DIR%/*}/ == "${PREFIX%/}/"* ]]; do
		INNER_GIT_DIR="${INNER_GIT_DIR%/*}"
	done
	[[ $(git -C "$INNER_GIT_DIR" rev-parse --is-inside-work-tree 2>/dev/null) == true ]] || INNER_GIT_DIR=""
}
git_add_file() {
	[[ -n $INNER_GIT_DIR ]] || return
	git -C "$INNER_GIT_DIR" add "$1" || return
	[[ -n $(git -C "$INNER_GIT_DIR" status --porcelain "$1") ]] || return
	git_commit "$2"
}
git_commit() {
	[[ -n $INNER_GIT_DIR ]] || return
	git -C "$INNER_GIT_DIR" commit -m "$1"
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
set_age_recipients() {
	AGE_RECIPIENT_ARGS=( )

	if [[ -n $PASSAGE_RECIPIENTS_FILE ]]; then
		AGE_RECIPIENT_ARGS+=( "-R" "$PASSAGE_RECIPIENTS_FILE" )
		return
	fi

	if [[ -n $PASSAGE_RECIPIENTS ]]; then
		for age_recipient in $PASSAGE_RECIPIENTS; do
			AGE_RECIPIENT_ARGS+=( "-r" "$age_recipient" )
		done
		return
	fi

	local current="$PREFIX/$1"
	while [[ $current != "$PREFIX" && ! -f $current/.age-recipients ]]; do
		current="${current%/*}"
	done
	current="$current/.age-recipients"

	if [[ ! -f $current ]]; then
		AGE_RECIPIENT_ARGS+=$AGE_IDENTITY_ARGS
		return
	fi

	AGE_RECIPIENT_ARGS+=( "-R" "$current" )
}

reencrypt_path() {
	local passfile
	while read -r -d "" passfile; do
		[[ -L $passfile ]] && continue
		local passfile_dir="${passfile%/*}"
		passfile_dir="${passfile_dir#$PREFIX}"
		passfile_dir="${passfile_dir#/}"
		local passfile_display="${passfile#$PREFIX/}"
		passfile_display="${passfile_display%.age}"
		local passfile_temp="${passfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"

		set_age_recipients "$passfile_dir"
		echo "$passfile_display: reencrypting with: age ${AGE_RECIPIENT_ARGS[@]}"
		$AGE -d "${AGE_IDENTITY_ARGS[@]}" "$passfile" | $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile_temp" &&
		mv "$passfile_temp" "$passfile" || rm -f "$passfile_temp"
	done < <(find "$1" -path '*/.git' -prune -o -iname '*.age' -print0)
}
check_sneaky_paths() {
	local path
	for path in "$@"; do
		[[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] && die "Error: You've attempted to pass a sneaky path to passage. Go home."
	done
}

#
# END helper functions
#

#
# BEGIN platform definable
#

clip() {
	if [[ -n $WAYLAND_DISPLAY ]] && command -v wl-copy &> /dev/null; then
		local copy_cmd=( wl-copy )
		local paste_cmd=( wl-paste -n )
		if [[ $X_SELECTION == primary ]]; then
			copy_cmd+=( --primary )
			paste_cmd+=( --primary )
		fi
		local display_name="$WAYLAND_DISPLAY"
	elif [[ -n $DISPLAY ]] && command -v xclip &> /dev/null; then
		local copy_cmd=( xclip -selection "$X_SELECTION" )
		local paste_cmd=( xclip -o -selection "$X_SELECTION" )
		local display_name="$DISPLAY"
	else
		die "Error: No X11 or Wayland display and clipper detected"
	fi
	local sleep_argv0="password store sleep on display $display_name"

	# This base64 business is because bash cannot store binary data in a shell
	# variable. Specifically, it cannot store nulls nor (non-trivally) store
	# trailing new lines.
	pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
	local before="$("${paste_cmd[@]}" 2>/dev/null | $BASE64)"
	echo -n "$1" | "${copy_cmd[@]}" || die "Error: Could not copy data to the clipboard"
	(
		( exec -a "$sleep_argv0" bash <<<"trap 'kill %1' TERM; sleep '$CLIP_TIME' & wait" )
		local now="$("${paste_cmd[@]}" | $BASE64)"
		[[ $now != $(echo -n "$1" | $BASE64) ]] && before="$now"

		# It might be nice to programatically check to see if klipper exists,
		# as well as checking for other common clipboard managers. But for now,
		# this works fine -- if qdbus isn't there or if klipper isn't running,
		# this essentially becomes a no-op.
		#
		# Clipboard managers frequently write their history out in plaintext,
		# so we axe it here:
		qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null

		echo "$before" | $BASE64 -d | "${copy_cmd[@]}"
	) >/dev/null 2>&1 & disown
	echo "Copied $2 to clipboard. Will clear in $CLIP_TIME seconds."
}

qrcode() {
	if [[ -n $DISPLAY || -n $WAYLAND_DISPLAY ]]; then
		if type feh >/dev/null 2>&1; then
			echo -n "$1" | qrencode --size 10 -o - | feh -x --title "pass: $2" -g +200+200 -
			return
		elif type gm >/dev/null 2>&1; then
			echo -n "$1" | qrencode --size 10 -o - | gm display -title "pass: $2" -geometry +200+200 -
			return
		elif type display >/dev/null 2>&1; then
			echo -n "$1" | qrencode --size 10 -o - | display -title "pass: $2" -geometry +200+200 -
			return
		fi
	fi
	echo -n "$1" | qrencode -t utf8
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
		trap remove_tmpfile EXIT
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
		trap shred_tmpfile EXIT
	fi

}
GETOPT="getopt"
SHRED="shred -f -z"
BASE64="base64"

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
	=   passage: age-backed password manager   =
	=                                          =
	=                  v1.7.4                  =
	=                                          =
	=             Filippo Valsorda             =
	=                                          =
	=        Based on password-store by        =
	=                                          =
	=             Jason A. Donenfeld           =
	=               Jason@zx2c4.com            =
	============================================
	_EOF
}

cmd_usage() {
	cmd_version
	echo
	cat <<-_EOF
	Usage:
	    $PROGRAM [ls] [subfolder]
	        List passwords.
	    $PROGRAM find pass-names...
	    	List passwords that match pass-names.
	    $PROGRAM [show] [--clip[=line-number],-c[line-number]] pass-name
	        Show existing password and optionally put it on the clipboard.
	        If put on the clipboard, it will be cleared in $CLIP_TIME seconds.
	    $PROGRAM grep [GREPOPTIONS] search-string
	        Search for password files containing search-string when decrypted.
	    $PROGRAM insert [--echo,-e | --multiline,-m] [--force,-f] pass-name
	        Insert new password. Optionally, echo the password back to the console
	        during entry. Or, optionally, the entry may be multiline. Prompt before
	        overwriting existing password unless forced.
	    $PROGRAM edit pass-name
	        Insert a new password or edit an existing password using ${EDITOR:-vi}.
	    $PROGRAM generate [--no-symbols,-n] [--clip,-c] [--in-place,-i | --force,-f] pass-name [pass-length]
	        Generate a new password of pass-length (or $GENERATED_LENGTH if unspecified) with optionally no symbols.
	        Optionally put it on the clipboard and clear board after $CLIP_TIME seconds.
	        Prompt before overwriting existing password unless forced.
	        Optionally replace only the first line of an existing file with a new password.
	    $PROGRAM reencrypt [--path=subfolder,-p subfolder]
	        Selectively reencrypt existing passwords.
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
	_EOF
}

cmd_reencrypt() {
	local opts path=""
	opts="$($GETOPT -o p: -l path: -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-p|--path) path="$2"; shift 2 ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || $# -ne 0 ]] && die "Usage: $PROGRAM $COMMAND [--path=subfolder,-p subfolder]"
	[[ -n $path ]] && check_sneaky_paths "$path"
	[[ -n $path && ! -d $PREFIX/$path && -e $PREFIX/$path ]] && die "Error: $PREFIX/$path exists but is not a directory."

	set_git "$PREFIX/$path"

	reencrypt_path "$PREFIX/$path"
	git_add_file "$PREFIX/$path" "Reencrypted $path."
}

cmd_show() {
	local opts selected_line clip=0 qrcode=0
	opts="$($GETOPT -o q::c:: -l qrcode::,clip:: -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-q|--qrcode) qrcode=1; selected_line="${2:-1}"; shift 2 ;;
		-c|--clip) clip=1; selected_line="${2:-1}"; shift 2 ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || ( $qrcode -eq 1 && $clip -eq 1 ) ]] && die "Usage: $PROGRAM $COMMAND [--clip[=line-number],-c[line-number]] [--qrcode[=line-number],-q[line-number]] [pass-name]"

	local pass
	local path="$1"
	local passfile="$PREFIX/$path.age"
	check_sneaky_paths "$path"
	if [[ -f $passfile ]]; then
		if [[ $clip -eq 0 && $qrcode -eq 0 ]]; then
			pass="$($AGE -d "${AGE_IDENTITY_ARGS[@]}" "$passfile" | $BASE64)" || exit $?
			echo "$pass" | $BASE64 -d
		else
			[[ $selected_line =~ ^[0-9]+$ ]] || die "Clip location '$selected_line' is not a number."
			pass="$($AGE -d "${AGE_IDENTITY_ARGS[@]}" "$passfile" | tail -n +${selected_line} | head -n 1)" || exit $?
			[[ -n $pass ]] || die "There is no password to put on the clipboard at line ${selected_line}."
			if [[ $clip -eq 1 ]]; then
				clip "$pass" "$path"
			elif [[ $qrcode -eq 1 ]]; then
				qrcode "$pass" "$path"
			fi
		fi
	elif [[ -d $PREFIX/$path ]]; then
		if [[ -z $path ]]; then
			echo "Passage"
		else
			echo "${path%\/}"
		fi
		tree -N -C -l --noreport "$PREFIX/$path" | tail -n +2 | sed -E 's/\.age(\x1B\[[0-9]+m)?( ->|$)/\1\2/g' # remove .age at end of line, but keep colors
	elif [[ -z $path ]]; then
		die "Error: password store is empty."
	else
		die "Error: $path is not in the password store."
	fi
}

cmd_find() {
	[[ $# -eq 0 ]] && die "Usage: $PROGRAM $COMMAND pass-names..."
	IFS="," eval 'echo "Search Terms: $*"'
	local terms="*$(printf '%s*|*' "$@")"
	tree -N -C -l --noreport -P "${terms%|*}" --prune --matchdirs --ignore-case "$PREFIX" | tail -n +2 | sed -E 's/\.age(\x1B\[[0-9]+m)?( ->|$)/\1\2/g'
}

cmd_grep() {
	[[ $# -lt 1 ]] && die "Usage: $PROGRAM $COMMAND [GREPOPTIONS] search-string"
	local passfile grepresults
	while read -r -d "" passfile; do
		grepresults="$($AGE -d "${AGE_IDENTITY_ARGS[@]}" "$passfile" | grep --color=always "$@")"
		[[ $? -ne 0 ]] && continue
		passfile="${passfile%.age}"
		passfile="${passfile#$PREFIX/}"
		local passfile_dir="${passfile%/*}/"
		[[ $passfile_dir == "${passfile}/" ]] && passfile_dir=""
		passfile="${passfile##*/}"
		printf "\e[94m%s\e[1m%s\e[0m:\n" "$passfile_dir" "$passfile"
		echo "$grepresults"
	done < <(find -L "$PREFIX" -path '*/.git' -prune -o -path '*/.extensions' -prune -o -iname '*.age' -print0)
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
	local path="${1%/}"
	local passfile="$PREFIX/$path.age"
	check_sneaky_paths "$path"
	set_git "$passfile"

	[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_age_recipients "$(dirname -- "$path")"

	if [[ $multiline -eq 1 ]]; then
		echo "Enter contents of $path and press Ctrl+D when finished:"
		echo
		$AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile" || die "Password encryption aborted."
	elif [[ $noecho -eq 1 ]]; then
		local password password_again
		while true; do
			read -r -p "Enter password for $path: " -s password || exit 1
			echo
			read -r -p "Retype password for $path: " -s password_again || exit 1
			echo
			if [[ $password == "$password_again" ]]; then
				echo "$password" | $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile" || die "Password encryption aborted."
				break
			else
				die "Error: the entered passwords do not match."
			fi
		done
	else
		local password
		read -r -p "Enter password for $path: " -e password
		echo "$password" | $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile" || die "Password encryption aborted."
	fi
	git_add_file "$passfile" "Add given password for $path to store."
}

cmd_edit() {
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND pass-name"

	local path="${1%/}"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_age_recipients "$(dirname -- "$path")"
	local passfile="$PREFIX/$path.age"
	set_git "$passfile"

	tmpdir #Defines $SECURE_TMPDIR
	local tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXXX")-${path//\//-}.txt"

	local action="Add"
	if [[ -f $passfile ]]; then
		$AGE -d -o "$tmp_file" "${AGE_IDENTITY_ARGS[@]}" "$passfile" || exit 1
		action="Edit"
	fi
	${EDITOR:-vi} "$tmp_file"
	[[ -f $tmp_file ]] || die "New password not saved."
	$AGE -d -o - "${AGE_IDENTITY_ARGS[@]}" "$passfile" 2>/dev/null | diff - "$tmp_file" &>/dev/null && die "Password unchanged."
	while ! $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile" "$tmp_file"; do
		yesno "Age encryption failed. Would you like to try again?"
	done
	git_add_file "$passfile" "$action password for $path using ${EDITOR:-vi}."
}

cmd_generate() {
	local opts qrcode=0 clip=0 force=0 characters="$CHARACTER_SET" inplace=0 pass
	opts="$($GETOPT -o nqcif -l no-symbols,qrcode,clip,in-place,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-n|--no-symbols) characters="$CHARACTER_SET_NO_SYMBOLS"; shift ;;
		-q|--qrcode) qrcode=1; shift ;;
		-c|--clip) clip=1; shift ;;
		-f|--force) force=1; shift ;;
		-i|--in-place) inplace=1; shift ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || ( $# -ne 2 && $# -ne 1 ) || ( $force -eq 1 && $inplace -eq 1 ) || ( $qrcode -eq 1 && $clip -eq 1 ) ]] && die "Usage: $PROGRAM $COMMAND [--no-symbols,-n] [--clip,-c] [--qrcode,-q] [--in-place,-i | --force,-f] pass-name [pass-length]"
	local path="$1"
	local length="${2:-$GENERATED_LENGTH}"
	check_sneaky_paths "$path"
	[[ $length =~ ^[0-9]+$ ]] || die "Error: pass-length \"$length\" must be a number."
	[[ $length -gt 0 ]] || die "Error: pass-length must be greater than zero."
	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_age_recipients "$(dirname -- "$path")"
	local passfile="$PREFIX/$path.age"
	set_git "$passfile"

	[[ $inplace -eq 0 && $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

	read -r -n $length pass < <(LC_ALL=C tr -dc "$characters" < /dev/urandom)
	[[ ${#pass} -eq $length ]] || die "Could not generate password from /dev/urandom."
	if [[ $inplace -eq 0 ]]; then
		echo "$pass" | $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile" || die "Password encryption aborted."
	else
		local passfile_temp="${passfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"
		if { echo "$pass"; $AGE -d "${AGE_IDENTITY_ARGS[@]}" "$passfile" | tail -n +2; } | $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile_temp"; then
			mv "$passfile_temp" "$passfile"
		else
			rm -f "$passfile_temp"
			die "Could not reencrypt new password."
		fi
	fi
	local verb="Add"
	[[ $inplace -eq 1 ]] && verb="Replace"
	git_add_file "$passfile" "$verb generated password for ${path}."

	if [[ $clip -eq 1 ]]; then
		clip "$pass" "$path"
	elif [[ $qrcode -eq 1 ]]; then
		qrcode "$pass" "$path"
	else
		printf "\e[1mThe generated password for \e[4m%s\e[24m is:\e[0m\n\e[1m\e[93m%s\e[0m\n" "$path" "$pass"
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

	local passdir="$PREFIX/${path%/}"
	local passfile="$PREFIX/$path.age"
	[[ -f $passfile && -d $passdir && $path == */ || ! -f $passfile ]] && passfile="${passdir%/}/"
	[[ -e $passfile ]] || die "Error: $path is not in the password store."
	set_git "$passfile"

	[[ $force -eq 1 ]] || yesno "Are you sure you would like to delete $path?"

	rm $recursive -f -v "$passfile"
	set_git "$passfile"
	if [[ -n $INNER_GIT_DIR && ! -e $passfile ]]; then
		git -C "$INNER_GIT_DIR" rm -qr "$passfile"
		set_git "$passfile"
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
	local old_dir="$old_path"
	local new_path="$PREFIX/$2"

	if ! [[ -f $old_path.age && -d $old_path && $1 == */ || ! -f $old_path.age ]]; then
		old_dir="${old_path%/*}"
		old_path="${old_path}.age"
	fi
	echo "$old_path"
	[[ -e $old_path ]] || die "Error: $1 is not in the password store."

	mkdir -p -v "${new_path%/*}"
	[[ -d $old_path || -d $new_path || $new_path == */ ]] || new_path="${new_path}.age"

	local interactive="-i"
	[[ ! -t 0 || $force -eq 1 ]] && interactive="-f"

	set_git "$new_path"
	if [[ $move -eq 1 ]]; then
		mv $interactive -v "$old_path" "$new_path" || exit 1
		[[ -e "$new_path" ]] && reencrypt_path "$new_path"

		set_git "$new_path"
		if [[ -n $INNER_GIT_DIR && ! -e $old_path ]]; then
			git -C "$INNER_GIT_DIR" rm -qr "$old_path" 2>/dev/null
			set_git "$new_path"
			git_add_file "$new_path" "Rename ${1} to ${2}."
		fi
		set_git "$old_path"
		if [[ -n $INNER_GIT_DIR && ! -e $old_path ]]; then
			git -C "$INNER_GIT_DIR" rm -qr "$old_path" 2>/dev/null
			set_git "$old_path"
			[[ -n $(git -C "$INNER_GIT_DIR" status --porcelain "$old_path") ]] && git_commit "Remove ${1}."
		fi
		rmdir -p "$old_dir" 2>/dev/null
	else
		cp $interactive -r -v "$old_path" "$new_path" || exit 1
		[[ -e "$new_path" ]] && reencrypt_path "$new_path"
		git_add_file "$new_path" "Copy ${1} to ${2}."
	fi
}

cmd_git() {
	set_git "$PREFIX/"
	if [[ $1 == "init" ]]; then
		INNER_GIT_DIR="$PREFIX"
		git -C "$INNER_GIT_DIR" "$@" || exit 1
		git_add_file "$PREFIX" "Add current contents of password store."

		echo '*.age diff=age' > "$PREFIX/.gitattributes"
		git_add_file .gitattributes "Configure git repository for age file diff."
		git -C "$INNER_GIT_DIR" config --local diff.age.binary true
		git -C "$INNER_GIT_DIR" config --local diff.age.textconv "$AGE -d -i ${IDENTITIES_FILE}"
	elif [[ -n $INNER_GIT_DIR ]]; then
		tmpdir nowarn #Defines $SECURE_TMPDIR. We don't warn, because at most, this only copies encrypted files.
		export TMPDIR="$SECURE_TMPDIR"
		git -C "$INNER_GIT_DIR" "$@"
	else
		die "Error: the password store is not a git repository. Try \"$PROGRAM git init\"."
	fi
}

cmd_extension_or_show() {
	if ! cmd_extension "$@"; then
		COMMAND="show"
		cmd_show "$@"
	fi
}

SYSTEM_EXTENSION_DIR=""
cmd_extension() {
	check_sneaky_paths "$1"
	local user_extension system_extension extension
	[[ -n $SYSTEM_EXTENSION_DIR ]] && system_extension="$SYSTEM_EXTENSION_DIR/$1.bash"
	[[ $PASSWORD_STORE_ENABLE_EXTENSIONS == true ]] && user_extension="$EXTENSIONS/$1.bash"
	if [[ -n $user_extension && -f $user_extension && -x $user_extension ]]; then
		extension="$user_extension"
	elif [[ -n $system_extension && -f $system_extension && -x $system_extension ]]; then
		extension="$system_extension"
	else
		return 1
	fi
	shift
	source "$extension" "$@"
	return 0
}

#
# END subcommand functions
#

PROGRAM="${0##*/}"
COMMAND="$1"

AGE_IDENTITY_ARGS=( )
if [[ -d "$IDENTITIES_FILE" ]]; then
	for f in $IDENTITIES_FILE/*; do
		AGE_IDENTITY_ARGS+=( "-i" "$f" )
	done
	IDENTITIES_FILE="${AGE_IDENTITY_ARGS[1]}"
else
	AGE_IDENTITY_ARGS+=( "-i" "$IDENTITIES_FILE" )
fi

if [[ ! -f "$IDENTITIES_FILE" ]]; then
	cat >&2 <<-_EOF
	Error: You must place an age identity at $IDENTITIES_FILE:
	    age-keygen -o $IDENTITIES_FILE
	before you may use the password store.

	_EOF
	cmd_usage
	exit 1
fi

case "$1" in
	init) shift;			cmd_init "$@" ;;
	help|--help) shift;		cmd_usage "$@" ;;
	version|--version) shift;	cmd_version "$@" ;;
	show|ls|list) shift;		cmd_show "$@" ;;
	find|search) shift;		cmd_find "$@" ;;
	grep) shift;			cmd_grep "$@" ;;
	insert|add) shift;		cmd_insert "$@" ;;
	edit) shift;			cmd_edit "$@" ;;
	generate) shift;		cmd_generate "$@" ;;
	reencrypt) shift;		cmd_reencrypt "$@" ;;
	delete|rm|remove) shift;	cmd_delete "$@" ;;
	rename|mv) shift;		cmd_copy_move "move" "$@" ;;
	copy|cp) shift;			cmd_copy_move "copy" "$@" ;;
	git) shift;			cmd_git "$@" ;;
	*)				cmd_extension_or_show "$@" ;;
esac
exit 0

# Copyright (C) 2014 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

clip() {
	local sleep_argv0="password store sleep on display $DISPLAY"
	pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
	local before="$(base64 < /dev/clipboard)"
	echo -n "$1" > /dev/clipboard
	(
		( exec -a "$sleep_argv0" sleep "$CLIP_TIME" )
		local now="$(base64 < /dev/clipboard)"
		[[ $now != $(echo -n "$1" | base64) ]] && before="$now"
		echo "$before" | base64 -d > /dev/clipboard
	) >/dev/null 2>&1 & disown
	echo "Copied $2 to clipboard. Will clear in $CLIP_TIME seconds."
}

# replaces Cygwin-style filenames with their Windows counterparts
gpg_winpath() {
	local args=("$@")
	# as soon as an argument (from back to front) is no file, it can only be a filename argument if it is preceeded by '-o'
	local could_be_filenames="true"
	local i
	for ((i=${#args[@]}-1; i>=0; i--)); do
		if ( [ $i -gt 0 ] && [ "${args[$i-1]}" = "-o" ] && [ "${args[$i]}" != "-" ] ); then
			args[$i]="$(cygpath -am "${args[$i]}")"
		elif [ $could_be_filenames = "true" ]; then
			if [ -e "${args[$i]}" ]; then
				args[$i]="$(cygpath -am "${args[$i]}")"
			else
				could_be_filenames="false"
			fi
		fi
	done
	$GPG_ORIG "${args[@]}"
}

if $GPG --help | grep -q 'Home: [A-Z]:[/\\]'; then
	GPG_ORIG="$GPG"
	GPG=gpg_winpath
fi

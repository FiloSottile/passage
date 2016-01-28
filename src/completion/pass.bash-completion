# completion file for bash

# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com> and
# Brian Mattern <rephorm@rephorm.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

_pass_complete_entries () {
	prefix="${PASSWORD_STORE_DIR:-$HOME/.password-store/}"
	prefix="${prefix%/}/"
	suffix=".gpg"
	autoexpand=${1:-0}

	local IFS=$'\n'
	local items=($(compgen -f $prefix$cur))

	# Remember the value of the first item, to see if it is a directory. If
	# it is a directory, then don't add a space to the completion
	local firstitem=""
	# Use counter, can't use ${#items[@]} as we skip hidden directories
	local i=0

	for item in ${items[@]}; do
		[[ $item =~ /\.[^/]*$ ]] && continue

		# if there is a unique match, and it is a directory with one entry
		# autocomplete the subentry as well (recursively)
		if [[ ${#items[@]} -eq 1 && $autoexpand -eq 1 ]]; then
			while [[ -d $item ]]; do
				local subitems=($(compgen -f "$item/"))
				local filtereditems=( )
				for item2 in "${subitems[@]}"; do
					[[ $item2 =~ /\.[^/]*$ ]] && continue
					filtereditems+=( "$item2" )
				done
				if [[ ${#filtereditems[@]} -eq 1 ]]; then
					item="${filtereditems[0]}"
				else
					break
				fi
			done
		fi

		# append / to directories
		[[ -d $item ]] && item="$item/"

		item="${item%$suffix}"
		COMPREPLY+=("${item#$prefix}")
		if [[ $i -eq 0 ]]; then
			firstitem=$item
		fi
		let i+=1
	done

	# The only time we want to add a space to the end is if there is only
	# one match, and it is not a directory
	if [[ $i -gt 1 || ( $i -eq 1 && -d $firstitem ) ]]; then
		compopt -o nospace
	fi
}

_pass_complete_folders () {
	prefix="${PASSWORD_STORE_DIR:-$HOME/.password-store/}"
	prefix="${prefix%/}/"

	local IFS=$'\n'
	local items=($(compgen -d $prefix$cur))
	for item in ${items[@]}; do
		[[ $item == $prefix.* ]] && continue
		COMPREPLY+=("${item#$prefix}/")
	done
}

_pass_complete_keys () {
	local IFS=$'\n'
	# Extract names and email addresses from gpg --list-keys
	local keys="$(gpg2 --list-secret-keys --with-colons | cut -d : -f 10 | sort -u | sed '/^$/d')"
	COMPREPLY+=($(compgen -W "${keys}" -- ${cur}))
}

_pass()
{
	COMPREPLY=()
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local commands="init ls find grep show insert generate edit rm mv cp git help version"
	if [[ $COMP_CWORD -gt 1 ]]; then
		local lastarg="${COMP_WORDS[$COMP_CWORD-1]}"
		case "${COMP_WORDS[1]}" in
			init)
				if [[ $lastarg == "-p" || $lastarg == "--path" ]]; then
					_pass_complete_folders
					compopt -o nospace
				else
					COMPREPLY+=($(compgen -W "-p --path" -- ${cur}))
					_pass_complete_keys
				fi
				;;
			ls|list|edit)
				_pass_complete_entries
				;;
			show|-*)
				COMPREPLY+=($(compgen -W "-c --clip" -- ${cur}))
				_pass_complete_entries 1
				;;
			insert)
				COMPREPLY+=($(compgen -W "-e --echo -m --multiline -f --force" -- ${cur}))
				_pass_complete_entries
				;;
			generate)
				COMPREPLY+=($(compgen -W "-n --no-symbols -c --clip -f --force -i --in-place" -- ${cur}))
				_pass_complete_entries
				;;
			cp|copy|mv|rename)
				COMPREPLY+=($(compgen -W "-f --force" -- ${cur}))
				_pass_complete_entries
				;;
			rm|remove|delete)
				COMPREPLY+=($(compgen -W "-r --recursive -f --force" -- ${cur}))
				_pass_complete_entries
				;;
			git)
				COMPREPLY+=($(compgen -W "init push pull config log reflog rebase" -- ${cur}))
				;;
		esac
	else
		COMPREPLY+=($(compgen -W "${commands}" -- ${cur}))
		_pass_complete_entries 1
	fi
}

complete -o filenames -F _pass pass

#!/bin/sh

# This is a super bootleg script for converting plaintext examples into groff.

while read line; do
	echo "$line" | while read -n 1 char; do
		if [[ $char == "%" ]]; then
			echo -n '%'
			continue
		fi
		ord=$(printf '%d' "'$char")
		if [[ $ord -eq 0 ]]; then
			printf ' '
		elif [[ $ord -gt 127 ]]; then
			printf '\[u%X]' "'$char"
		else
			printf "$char"
		fi
	done
	echo
	echo ".br"
done

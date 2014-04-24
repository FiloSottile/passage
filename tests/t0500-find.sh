#!/usr/bin/env bash

test_description='Find check'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Make sure find resolves correct files' '
	"$PASS" init $KEY1 &&
	"$PASS" generate Something/neat 19 &&
	"$PASS" generate Anotherthing/okay 38 &&
	"$PASS" generate Fish 12 &&
	"$PASS" generate Fishthings 122 &&
	"$PASS" generate Fishies/stuff 21 &&
	"$PASS" generate Fishies/otherstuff 1234 &&
	[[ $("$PASS" find fish | sed "s/^[ \`|-]*//g;s/$(printf \\x1b)\\[[0-9;]*[a-zA-Z]//g" | tr "\\n" -) == "Search Terms: fish-Fish-Fishies-otherstuff-stuff-Fishthings-" ]]
'

test_done

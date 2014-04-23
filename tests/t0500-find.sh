#!/bin/bash

test_description='Find check'
. ./setup.sh

test_expect_success 'Make sure find resolves correct files' '
	pass init $KEY1 &&
	pass generate Something/neat 19 &&
	pass generate Anotherthing/okay 38 &&
	pass generate Fish 12 &&
	pass generate Fishthings 122 &&
	pass generate Fishies/stuff 21 &&
	pass generate Fishies/otherstuff 1234 &&
	[[ $(pass find fish | sed "s/^[ \`|-]*//g;s/\\x1B\\[[0-9;]*[a-zA-Z]//g" | tr "\\n" -) == "Search Terms: fish-Fish-Fishies-otherstuff-stuff-Fishthings-" ]]
'

test_done

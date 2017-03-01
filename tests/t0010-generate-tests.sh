#!/usr/bin/env bash

test_description='Test generate'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Test "generate" command' '
	"$PASS" init $KEY1 &&
	"$PASS" generate cred 19 &&
	[[ $("$PASS" show cred | wc -m) -eq 20 ]]
'

test_expect_success 'Test replacement of first line' '
	"$PASS" insert -m cred2 <<<"$(printf "this is a big\\npassword\\nwith\\nmany\\nlines\\nin it bla bla")" &&
	"$PASS" generate -i cred2 23 &&
	[[ $("$PASS" show cred2) == "$(printf "%s\\npassword\\nwith\\nmany\\nlines\\nin it bla bla" "$("$PASS" show cred2 | head -n 1)")" ]]
'

test_done

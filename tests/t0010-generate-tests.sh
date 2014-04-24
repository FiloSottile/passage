#!/usr/bin/env bash

test_description='Test generate'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Test "generate" command' '
	"$PASS" init $KEY1 &&
	"$PASS" generate cred 19 &&
	[[ $("$PASS" show cred | wc -m) -eq 20 ]]
'

test_done

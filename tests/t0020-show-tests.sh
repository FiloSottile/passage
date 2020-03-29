#!/usr/bin/env bash

test_description='Test show'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Test "show" command' '
	"$PASS" init $KEY1 &&
	"$PASS" generate cred1 20 &&
	"$PASS" show cred1
'

test_expect_success 'Test "show" command with spaces' '
	"$PASS" insert -e "I am a cred with lots of spaces"<<<"BLAH!!" &&
	[[ $("$PASS" show "I am a cred with lots of spaces") == "BLAH!!" ]]
'

test_expect_success 'Test "show" command with unicode' '
	"$PASS" generate 🏠 &&
	"$PASS" show | grep -q '🏠'
'

test_expect_success 'Test "show" of nonexistant password' '
	test_must_fail "$PASS" show cred2
'

test_done

#!/usr/bin/env bash

test_description='Test insert'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Test "insert" command' '
	"$PASS" init $KEY1 &&
	echo "Hello world" | "$PASS" insert -e cred1 &&
	[[ $("$PASS" show cred1) == "Hello world" ]]
'

test_done

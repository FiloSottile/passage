#!/usr/bin/env bash

test_description='Test edit'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Test "edit" command' '
	"$PASS" init $KEY1 &&
	"$PASS" generate cred1 90 &&
	export FAKE_EDITOR_PASSWORD="big fat fake password" &&
	export PATH="$TEST_HOME:$PATH"
	export EDITOR="fake-editor-change-password.sh" &&
	"$PASS" edit cred1 &&
	[[ $("$PASS" show cred1) == "$FAKE_EDITOR_PASSWORD" ]]
'

test_done

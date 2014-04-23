#!/bin/bash

test_description='Test edit'
. ./setup.sh

test_expect_success 'Test "edit" command' '
	pass init $KEY1 &&
	pass generate cred1 90 &&
	export FAKE_EDITOR_PASSWORD="big fat fake password" &&
	export EDITOR="$TEST_HOME/fake-editor-change-password.sh" &&
	pass edit cred1 &&
	[[ $(pass show cred1) == "$FAKE_EDITOR_PASSWORD" ]]
'

test_done

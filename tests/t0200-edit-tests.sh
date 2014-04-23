#!/bin/bash

test_description='Test edit'
. ./setup.sh

TEST_CRED="test_cred"

test_expect_success 'Test "edit" command' '
	pass_init &&
	create_cred "$TEST_CRED" &&
	export FAKE_EDITOR_PASSWORD="big fat fake password" &&
	export EDITOR="$TEST_HOME/fake-editor-change-password.sh" &&
	$PASS edit "$TEST_CRED" &&
	verify_password "$TEST_CRED" "$FAKE_EDITOR_PASSWORD" 
'

test_done

#!/bin/bash

test_description='Test show'
. ./setup.sh

test_expect_success 'Test "show" command' '
	"$PASS" init $KEY1 &&
	"$PASS" generate cred1 20 &&
	"$PASS" show cred1
'

test_expect_success 'Test "show" of nonexistant password' '
	test_must_fail "$PASS" show cred2
'

test_done

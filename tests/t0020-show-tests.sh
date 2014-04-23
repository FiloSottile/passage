#!/bin/bash

test_description='Test show'
. ./setup.sh

test_expect_success 'Test "show" command' '
	pass init $KEY1 &&
	pass generate cred1 20 &&
	pass show cred1
'

test_expect_success 'Test "show" of nonexistant password' '
	test_must_fail pass show cred2
'

test_done

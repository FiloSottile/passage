#!/bin/sh

test_description='Test show'
. ./setup.sh

export TEST_CRED="test_cred"

test_expect_success 'Test "show" command' '
	pass_init &&
	create_cred "$TEST_CRED" &&
	${PASS} show "$TEST_CRED"
'

test_expect_success 'Test "show" of nonexistant password' '
	pass_init &&
	test_must_fail ${PASS} show "$TEST_CRED"
'
test_done

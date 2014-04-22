#!/bin/sh

test_description='Test rm'
. ./setup.sh

export TEST_CRED="test_cred"

test_expect_success 'Test "rm" command' '
	pass_init &&
	create_cred "${TEST_CRED}" &&
	echo "Removing $TEST_CRED" &&
	echo "y" | ${PASS} rm "${TEST_CRED}" &&
	check_no_cred "${TEST_CRED}"
'

test_expect_success 'Test "rm" of non-existent password' '
	test_must_fail ${PASS} rm does-not-exist
'

test_done

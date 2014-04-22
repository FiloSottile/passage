#!/bin/sh

test_description='Test mv'
. ./setup.sh

export TEST_CRED="test_cred"
export TEST_CRED_NEW="test_cred_new"

test_expect_success 'Test "mv" command' '
	pass_init &&
	create_cred "${TEST_CRED}" &&
	echo "Moving $TEST_CRED to $TEST_CRED_NEW" &&
	${PASS} mv "${TEST_CRED}" "${TEST_CRED_NEW}" &&
	check_cred "${TEST_CRED_NEW}" &&
	check_no_cred "${TEST_CRED}"
'

test_done

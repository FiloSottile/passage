#!/bin/bash

test_description='Test generate'
. ./setup.sh

export TEST_CRED="test_cred"
export TEST_CRED_LEN=24

test_expect_success 'Test "generate" command' '
	pass_init &&
	echo Generating credential "${TEST_CRED}" with length ${TEST_CRED_LEN} &&
	${PASS} generate "${TEST_CRED}" ${TEST_CRED_LEN} &&
	check_cred "${TEST_CRED}"
'

test_done

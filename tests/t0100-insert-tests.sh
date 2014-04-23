#!/bin/bash

test_description='Test insert'
. ./setup.sh

TEST_CRED="test_cred"
TEST_PASSWORD="Hello world"

test_expect_success 'Test "insert" command' '
	pass_init &&
	echo "$TEST_PASSWORD" | $PASS insert -e "$TEST_CRED" &&
	verify_password "$TEST_CRED" "$TEST_PASSWORD"
'

test_done

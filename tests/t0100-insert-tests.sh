#!/bin/bash

test_description='Test insert'
. ./setup.sh

test_expect_success 'Test "insert" command' '
	$PASS init $KEY1 &&
	echo "Hello world" | $PASS insert -e cred1 &&
	[[ $($PASS show cred1) == "Hello world" ]]
'

test_done

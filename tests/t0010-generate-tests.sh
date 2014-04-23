#!/bin/bash

test_description='Test generate'
. ./setup.sh

test_expect_success 'Test "generate" command' '
	pass init $KEY1 &&
	$PASS generate cred 19 &&
	[[ $($PASS show cred | wc -m) -eq 20 ]]
'

test_done

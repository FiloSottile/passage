#!/bin/bash

test_description='Test insert'
. ./setup.sh

test_expect_success 'Test "insert" command' '
	pass init $KEY1 &&
	echo "Hello world" | pass insert -e cred1 &&
	[[ $(pass show cred1) == "Hello world" ]]
'

test_done

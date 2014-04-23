#!/bin/bash

test_description='Test rm'
. ./setup.sh

test_expect_success 'Test "rm" command' '
	pass init $KEY1 &&
	pass generate cred1 43 &&
	echo "y" | pass rm cred1 &&
	[[ ! -e $PASSWORD_STORE_DIR/cred1.gpg ]]
'

test_expect_success 'Test "rm" of non-existent password' '
	test_must_fail pass rm does-not-exist
'

test_done

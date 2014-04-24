#!/bin/bash

test_description='Test rm'
. ./setup.sh

test_expect_success 'Test "rm" command' '
	"$PASS" init $KEY1 &&
	"$PASS" generate cred1 43 &&
	echo "y" | "$PASS" rm cred1 &&
	[[ ! -e $PASSWORD_STORE_DIR/cred1.gpg ]]
'

test_expect_success 'Test "rm" of non-existent password' '
	test_must_fail "$PASS" rm does-not-exist
'

test_done

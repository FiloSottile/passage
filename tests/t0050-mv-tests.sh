#!/bin/bash

test_description='Test mv'
. ./setup.sh

TEST_CRED="test_cred"
TEST_CRED_NEW="test_cred_new"

test_expect_success 'Test "mv" command' '
	pass init $KEY1 &&
	pass generate cred1 39 &&
	pass mv cred1 cred2 &&
	[[ -e $PASSWORD_STORE_DIR/cred2.gpg && ! -e $PASSWORD_STORE_DIR/cred1.gpg ]]
'

test_done

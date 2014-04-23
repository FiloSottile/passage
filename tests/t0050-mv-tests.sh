#!/bin/bash

test_description='Test mv'
. ./setup.sh

TEST_CRED="test_cred"
TEST_CRED_NEW="test_cred_new"

test_expect_success 'Test "mv" command' '
	$PASS init $KEY1 &&
	$PASS generate cred1 39 &&
	$PASS mv cred1 cred2 &&
	[[ -e $PASSWORD_STORE_DIR/cred2.gpg && ! -e $PASSWORD_STORE_DIR/cred1.gpg ]]
'

test_done

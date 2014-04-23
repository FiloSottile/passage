#!/bin/bash

test_description='Test mv command'
. ./setup.sh

INITIAL_PASSWORD="bla bla bla will we make it!!"

test_expect_success 'Basic move command' '
	pass init $KEY1 &&
	pass git init &&
	pass insert -e cred1 <<<"$INITIAL_PASSWORD" &&
	pass mv cred1 cred2 &&
	[[ -e $PASSWORD_STORE_DIR/cred2.gpg && ! -e $PASSWORD_STORE_DIR/cred1.gpg ]]
'

test_expect_success 'Directory creation' '
	pass mv cred2 directory/ &&
	[[ -d $PASSWORD_STORE_DIR/directory && -e $PASSWORD_STORE_DIR/directory/cred2.gpg ]]
'

test_expect_success 'Directory creation with file rename and empty directory removal' '
	pass mv directory/cred2 newdirectory/cred &&
	[[ -d $PASSWORD_STORE_DIR/newdirectory && -e $PASSWORD_STORE_DIR/newdirectory/cred.gpg && ! -e $PASSWORD_STORE_DIR/directory ]]
'

test_expect_success 'Directory rename' '
	pass mv newdirectory anotherdirectory &&
	[[ -d $PASSWORD_STORE_DIR/anotherdirectory && -e $PASSWORD_STORE_DIR/anotherdirectory/cred.gpg && ! -e $PASSWORD_STORE_DIR/newdirectory ]]
'

test_expect_success 'Directory move into new directory' '
	pass mv anotherdirectory newdirectory/ &&
	[[ -d $PASSWORD_STORE_DIR/newdirectory/anotherdirectory && -e $PASSWORD_STORE_DIR/newdirectory/anotherdirectory/cred.gpg && ! -e $PASSWORD_STORE_DIR/anotherdirectory ]]
'

test_expect_success 'Multi-directory creation and multi-directory empty removal' '
	pass mv newdirectory/anotherdirectory/cred new1/new2/new3/new4/thecred &&
	pass mv new1/new2/new3/new4/thecred cred &&
	[[ ! -d $PASSWORD_STORE_DIR/newdirectory/anotherdirectory && ! -d $PASSWORD_STORE_DIR/new1/new2/new3/new4 && -e $PASSWORD_STORE_DIR/cred.gpg ]]
'

test_expect_success 'Password made it until the end' '
	[[ $(pass show cred) == "$INITIAL_PASSWORD" ]]
'

test_expect_success 'Git is consistent' '
	[[ -z $(git status --porcelain 2>&1) ]]
'

test_done

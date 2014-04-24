#!/usr/bin/env bash

test_description='Test mv command'
cd "$(dirname "$0")"
. ./setup.sh

INITIAL_PASSWORD="bla bla bla will we make it!!"

test_expect_success 'Basic move command' '
	"$PASS" init $KEY1 &&
	"$PASS" git init &&
	"$PASS" insert -e cred1 <<<"$INITIAL_PASSWORD" &&
	"$PASS" mv cred1 cred2 &&
	[[ -e $PASSWORD_STORE_DIR/cred2.gpg && ! -e $PASSWORD_STORE_DIR/cred1.gpg ]]
'

test_expect_success 'Directory creation' '
	"$PASS" mv cred2 directory/ &&
	[[ -d $PASSWORD_STORE_DIR/directory && -e $PASSWORD_STORE_DIR/directory/cred2.gpg ]]
'

test_expect_success 'Directory creation with file rename and empty directory removal' '
	"$PASS" mv directory/cred2 "new directory with spaces"/cred &&
	[[ -d $PASSWORD_STORE_DIR/"new directory with spaces" && -e $PASSWORD_STORE_DIR/"new directory with spaces"/cred.gpg && ! -e $PASSWORD_STORE_DIR/directory ]]
'

test_expect_success 'Directory rename' '
	"$PASS" mv "new directory with spaces" anotherdirectory &&
	[[ -d $PASSWORD_STORE_DIR/anotherdirectory && -e $PASSWORD_STORE_DIR/anotherdirectory/cred.gpg && ! -e $PASSWORD_STORE_DIR/"new directory with spaces" ]]
'

test_expect_success 'Directory move into new directory' '
	"$PASS" mv anotherdirectory "new directory with spaces"/ &&
	[[ -d $PASSWORD_STORE_DIR/"new directory with spaces"/anotherdirectory && -e $PASSWORD_STORE_DIR/"new directory with spaces"/anotherdirectory/cred.gpg && ! -e $PASSWORD_STORE_DIR/anotherdirectory ]]
'

test_expect_success 'Multi-directory creation and multi-directory empty removal' '
	"$PASS" mv "new directory with spaces"/anotherdirectory/cred new1/new2/new3/new4/thecred &&
	"$PASS" mv new1/new2/new3/new4/thecred cred &&
	[[ ! -d $PASSWORD_STORE_DIR/"new directory with spaces"/anotherdirectory && ! -d $PASSWORD_STORE_DIR/new1/new2/new3/new4 && -e $PASSWORD_STORE_DIR/cred.gpg ]]
'

test_expect_success 'Password made it until the end' '
	[[ $("$PASS" show cred) == "$INITIAL_PASSWORD" ]]
'

test_expect_success 'Git is consistent' '
	[[ -z $(git status --porcelain 2>&1) ]]
'

test_done

#!/bin/bash

test_description='Reencryption consistency'
. ./setup.sh

INITIAL_PASSWORD="will this password live? a big question indeed..."

test_expect_success 'Init with key1' '
	pass_init
'

test_expect_success 'Root key encryption' '
	$PASS insert -e folder/cred1 <<<"$INITIAL_PASSWORD" &&
	[[ $(canonicalize_gpg_keys "$KEY1") == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root single key' '
	$PASS init $KEY2 &&
	[[ $(canonicalize_gpg_keys "$KEY2") == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root multiple key' '
	$PASS init $KEY2 $KEY3 $KEY1 &&
	[[ $(canonicalize_gpg_keys $KEY2 $KEY3 $KEY1) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root multiple key with string' '
	$PASS init $KEY2 $KEY3 $KEY1 "pass test key 4" &&
	[[ $(canonicalize_gpg_keys $KEY2 $KEY3 $KEY1 $KEY4) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group' '
	$PASS init group1 &&
	[[ $(gpg_keys_from_group group1) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group with spaces' '
	$PASS init "big group" &&
	[[ $(gpg_keys_from_group "big group") == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group with spaces and other keys' '
	$PASS init "big group" $KEY3 $KEY1 $KEY2 &&
	[[ $(canonicalize_gpg_keys $KEY3 $KEY1 $KEY2 $(gpg_keys_from_group "big group")) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group and other keys' '
	$PASS init group2 $KEY3 $KEY1 $KEY2 &&
	[[ $(canonicalize_gpg_keys $KEY3 $KEY1 $KEY2 $(gpg_keys_from_group group2)) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group to identical individual with no file change' '
	oldfile="$SHARNESS_TRASH_DIRECTORY/$RANDOM.$RANDOM.$RANDOM.$RANDOM.$RANDOM" &&
	$PASS init group1 &&
	cp "$PASSWORD_STORE_DIR/folder/cred1.gpg" "$oldfile" &&
	$PASS init $KEY4 $KEY2 &&
	test_cmp "$PASSWORD_STORE_DIR/folder/cred1.gpg" "$oldfile"
'

test_expect_success 'Reencryption subfolder multiple keys, copy' '
	$PASS init -p anotherfolder $KEY3 $KEY1 &&
	$PASS cp folder/cred1 anotherfolder/ &&
	[[ $(canonicalize_gpg_keys $KEY1 $KEY3) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/anotherfolder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption subfolder multiple keys, move, deinit' '
	$PASS init -p anotherfolder2 $KEY3 $KEY4 $KEY2 &&
	$PASS mv -f anotherfolder anotherfolder2/ &&
	[[ $(canonicalize_gpg_keys $KEY1 $KEY3) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/anotherfolder2/anotherfolder/cred1.gpg")" ]] &&
	$PASS init -p anotherfolder2/anotherfolder "" &&
	[[ $(canonicalize_gpg_keys $KEY3 $KEY4 $KEY2) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/anotherfolder2/anotherfolder/cred1.gpg")" ]]
'

#TODO: test with more varieties of move and copy!

test_expect_success 'Password lived through all transformations' '
	[[ $($PASS show anotherfolder2/anotherfolder/cred1) == "$INITIAL_PASSWORD" ]]
'

test_done


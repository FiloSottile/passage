#!/bin/bash

test_description='Reencryption consistency'
. ./setup.sh

INITIAL_PASSWORD="will this password live? a big question indeed..."

canonicalize_gpg_keys() {
	gpg --list-keys --keyid-format long "$@" | sed -n 's/sub *.*\/\([A-F0-9]\{16\}\) .*/\1/p' | sort -u
}
gpg_keys_from_encrypted_file() {
	gpg -v --list-only --keyid-format long "$1" 2>&1 | cut -d ' ' -f 5 | sort -u
}
gpg_keys_from_group() {
	local output="$(gpg --list-config --with-colons | sed -n "s/^cfg:group:$1:\\(.*\\)/\\1/p" | head -n 1)"
	local saved_ifs="$IFS"
	IFS=";"
	local keys=( $output )
	IFS="$saved_ifs"
	canonicalize_gpg_keys "${keys[@]}"
}

test_expect_success 'Setup initial key and git' '
	pass init $KEY1 && pass git init
'

test_expect_success 'Root key encryption' '
	pass insert -e folder/cred1 <<<"$INITIAL_PASSWORD" &&
	[[ $(canonicalize_gpg_keys "$KEY1") == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root single key' '
	pass init $KEY2 &&
	[[ $(canonicalize_gpg_keys "$KEY2") == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root multiple key' '
	pass init $KEY2 $KEY3 $KEY1 &&
	[[ $(canonicalize_gpg_keys $KEY2 $KEY3 $KEY1) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root multiple key with string' '
	pass init $KEY2 $KEY3 $KEY1 "pass test key 4" &&
	[[ $(canonicalize_gpg_keys $KEY2 $KEY3 $KEY1 $KEY4) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group' '
	pass init group1 &&
	[[ $(gpg_keys_from_group group1) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group with spaces' '
	pass init "big group" &&
	[[ $(gpg_keys_from_group "big group") == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group with spaces and other keys' '
	pass init "big group" $KEY3 $KEY1 $KEY2 &&
	[[ $(canonicalize_gpg_keys $KEY3 $KEY1 $KEY2 $(gpg_keys_from_group "big group")) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group and other keys' '
	pass init group2 $KEY3 $KEY1 $KEY2 &&
	[[ $(canonicalize_gpg_keys $KEY3 $KEY1 $KEY2 $(gpg_keys_from_group group2)) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/folder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption root group to identical individual with no file change' '
	oldfile="$SHARNESS_TRASH_DIRECTORY/$RANDOM.$RANDOM.$RANDOM.$RANDOM.$RANDOM" &&
	pass init group1 &&
	cp "$PASSWORD_STORE_DIR/folder/cred1.gpg" "$oldfile" &&
	pass init $KEY4 $KEY2 &&
	test_cmp "$PASSWORD_STORE_DIR/folder/cred1.gpg" "$oldfile"
'

test_expect_success 'Reencryption subfolder multiple keys, copy' '
	pass init -p anotherfolder $KEY3 $KEY1 &&
	pass cp folder/cred1 anotherfolder/ &&
	[[ $(canonicalize_gpg_keys $KEY1 $KEY3) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/anotherfolder/cred1.gpg")" ]]
'

test_expect_success 'Reencryption subfolder multiple keys, move, deinit' '
	pass init -p anotherfolder2 $KEY3 $KEY4 $KEY2 &&
	pass mv -f anotherfolder anotherfolder2/ &&
	[[ $(canonicalize_gpg_keys $KEY1 $KEY3) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/anotherfolder2/anotherfolder/cred1.gpg")" ]] &&
	pass init -p anotherfolder2/anotherfolder "" &&
	[[ $(canonicalize_gpg_keys $KEY3 $KEY4 $KEY2) == "$(gpg_keys_from_encrypted_file "$PASSWORD_STORE_DIR/anotherfolder2/anotherfolder/cred1.gpg")" ]]
'

#TODO: test with more varieties of move and copy!

test_expect_success 'Password lived through all transformations' '
	[[ $(pass show anotherfolder2/anotherfolder/cred1) == "$INITIAL_PASSWORD" ]]
'

test_expect_success 'Git picked up all changes throughout' '
	[[ -z $(git status --porcelain 2>&1) ]]
'

test_done

# This file should be sourced by all test-scripts
#
# This scripts sets the following:
#   $GNUPGHOME			Full path to test GPG directory
#   $PASS			Full path to password-store script to test
#   $GPG			Name of gpg executable
#   $PASSWORD_STORE_KEY		GPG key id of testing key
#   $PASSWORD_STORE_TEST_HOME	This folder

#
# Constants

PASSWORD_STORE_TEST_HOME="$(cd "$(dirname "$BASH_SOURCE")"; pwd)"

#
# Find the pass script

PASS="${PASSWORD_STORE_TEST_HOME}/../src/password-store.sh"

if [[ ! -e $PASS ]]; then
	echo "Could not find password-store.sh"
	exit 1
fi

#
# GnuPG configuration

# Where the test keyring and test key id
# Note: the assumption is the test key is unencrypted.
export GNUPGHOME="${PASSWORD_STORE_TEST_HOME}/gnupg/"
chmod 700 "$GNUPGHOME"
export PASSWORD_STORE_KEY="3DEEA12D"  # "Password-store Test Key"
GPG="gpg"
which gpg2 &>/dev/null && GPG="gpg2"

# We don't want to use any running agent.
# We want an agent to appear to pass to be running.
# We don't need a real agent. Hence:
export GPG_AGENT_INFO=" "

# pass_init()
#
# Initialize a password store, setting PASSWORD_STORE_DIR
#
# Arguments: None
# Returns: Nothing, sets PASSWORD_STORE_DIR
pass_init() {
	export PASSWORD_STORE_DIR="${SHARNESS_TRASH_DIRECTORY}/test-store/"
	echo "Initializing test password store (${PASSWORD_STORE_DIR}) with key ${PASSWORD_STORE_KEY}"

	if [[ -d "${PASSWORD_STORE_DIR}" ]] ; then
		echo "Removing old store"
		rm -rf "${PASSWORD_STORE_DIR}"
		if [[ -d "${PASSWORD_STORE_DIR}" ]] ; then
			echo "Removal failed."
			return 1
		fi
	fi

	$PASS init ${PASSWORD_STORE_KEY} || return 1

	echo "Initialization of ${PASSWORD_STORE_DIR} complete."
}

# check_cred()
#
# Check to make sure the given credential looks valid.
# Meaning it exists and has at least one line.
#
# Arguments: <credential name>
# Returns: 0 if valid looking, 1 otherwise
check_cred() {
	if [[ "$#" -ne 1 ]]; then
		echo "$0: Bad arguments"
		return 1
	fi
	local cred="$1"
	shift
	echo "Checking credential ${cred}"
	if ! $PASS show "$cred"; then
		echo "Credential ${cred} does not exist"
		return 1
	fi
	if [[ -z "$($PASS show "$cred")" ]]; then
		echo "Credential ${cred} empty"
		return 1
	fi
}

# check_no_cred()
#
# Check to make sure the given credential does not exist.
# Use to validate removal, moving, etc.
#
# Arguments: <credential name>
# Returns: 0 if credential does not exist, 1 otherwise
check_no_cred() {
	if [[ "$#" -ne 1 ]]; then
		echo "$0: Bad arguments"
		return 1
	fi
	local cred="$1"
	shift
	echo "Checking for lack of credential ${cred}"
	$PASS show "$cred" || return 0 
	echo "Credential ${cred} exists."
	return 1
}

# create_cred()
#
# Create a credential with the given name and, optionally, password.
# Credential must not already exist.
#
# Arguments: <credential name> [<password>]
# Returns: 0 on success, 1 otherwise.
create_cred() {
	if ! [[ "$#" -gt 0 && "$#" -lt 3 ]]; then
		echo "$0: Bad arguments"
		return 1
	fi
	local cred="$1"
	shift
	echo "Creating credential ${cred}"
	if ! check_no_cred "$cred"; then
		echo "Credential already exists"
		return 1
	fi
	if [[ "$#" -eq 1 ]]; then
		local password="$1"
		shift
		echo "Using password \"$password\" for $cred"
		$PASS insert -f -e "$cred" <<<"$password" || return 1
	else
		echo "Generating random password for $cred"
		if ! $PASS generate -f "${cred}" 24 > /dev/null; then
			echo "Failed to create credential ${cred}"
			return 1
		fi
	fi
	return 0
}

# verify_password()
#
# Verify a given credential exists and has the given password.
#
# Arguments: <credential name> <password>
# Returns: 0 on success, 1 otherwise.
verify_password() {
	if [[ "$#" -ne 2 ]]; then
		echo "$0: Bad arguments"
		return 1
	fi
	local cred="$1"
	shift
	local expected="$1"
	shift
	echo "Verifing credential ${cred} has password \"${expected}\""
	check_cred "$cred" || return 1
	local actualfile="${SHARNESS_TRASH_DIRECTORY}/verify-password-actual.$RANDOM.$RANDOM.$RANDOM.$RANDOM"
	local expectedfile="${SHARNESS_TRASH_DIRECTORY}/verify-password-expected.$RANDOM.$RANDOM.$RANDOM.$RANDOM"
	$PASS show "$TEST_CRED" | sed -n 1p > "$actualfile" &&
	echo "$expected" > "$expectedfile" &&
	test_cmp "$expectedfile" "$actualfile"
}

# canonicalize_gpg_keys()
#
# Resolves key names to key ids.
#
# Arguments: <key name>...
# Returns: 0, and echos keys on new lines
canonicalize_gpg_keys() {
	$GPG --list-keys --keyid-format long "$@" | sed -n 's/sub *.*\/\([A-F0-9]\{16\}\) .*/\1/p' | sort -u
}

# gpg_keys_from_encrypted_file()
#
# Finds keys used to encrypt a .gpg file.
#
# Arguments: <gpg file>
# Returns 0, and echos keys on new lines
gpg_keys_from_encrypted_file() {
	$GPG -v --list-only --keyid-format long "$1" 2>&1 | cut -d ' ' -f 5 | sort -u
}

# gpg_keys_from_group()
#
# Finds keys used in gpg.conf group
#
# Arguments: <group>
# Returns: 0, and echos keys on new lines
gpg_keys_from_group() {
	local output="$($GPG --list-config --with-colons | sed -n "s/^cfg:group:$1:\\(.*\\)/\\1/p" | head -n 1)"
	local saved_ifs="$IFS"
	IFS=";"
	local keys=( $output )
	IFS="$saved_ifs"
	canonicalize_gpg_keys "${keys[@]}"
}

# Initialize the test harness
. ./sharness.sh

#!/usr/bin/env bash
# Fake editor program for testing 'pass edit'.
# Changes password to 'Hello World', leaving rest of file intact.
#
# Intended use:
#   export FAKE_EDITOR_PASSWORD="blah blah blah"
#   export EDITOR=fake-editor-change-password.sh
#   $EDITOR <password file>
#
# Arguments: <filename>
# Returns: 0 on success, 1 on error

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <filename>"
	exit 1
fi

filename=$1 ; shift ;
new_password="${FAKE_EDITOR_PASSWORD:-Hello World}"

# And change only first line of file
# -i.tmp allows editing file in place. Extension needed on Mac OSX
sed -i.tmp "1 s/^.*\$/$new_password/g" "$filename"

exit 0

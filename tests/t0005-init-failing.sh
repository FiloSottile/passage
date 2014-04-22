#!/bin/bash

test_description='Show "pass init" returning non-zero bug(?) (XXX: remove this test?)'
. ./setup.sh

test_expect_failure 'Show "pass init" returning non-zero' '
	export PASSWORD_STORE_DIR="${SHARNESS_TRASH_DIRECTORY}/test-store/" &&
	${PASS} init ${PASSWORD_STORE_KEY}
'

test_done

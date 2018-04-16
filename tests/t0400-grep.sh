#!/usr/bin/env bash

test_description='Grep check'
cd "$(dirname "$0")"
. ./setup.sh

test_expect_success 'Make sure grep prints normal lines' '
	"$PASS" init $KEY1 &&
	"$PASS" insert -e blah1 <<<"hello" &&
	"$PASS" insert -e blah2 <<<"my name is" &&
	"$PASS" insert -e folder/blah3 <<<"I hate computers" &&
	"$PASS" insert -e blah4 <<<"me too!" &&
	"$PASS" insert -e folder/where/blah5 <<<"They are hell" &&
	results="$("$PASS" grep hell)" &&
	[[ $(wc -l <<<"$results") -eq 4 ]] &&
	grep -q blah5 <<<"$results" &&
	grep -q blah1 <<<"$results" &&
	grep -q "They are" <<<"$results"
'

test_expect_success 'Test passing the "-i" option to grep' '
	"$PASS" init $KEY1 &&
	"$PASS" insert -e blah1 <<<"I wonder..." &&
	"$PASS" insert -e blah2 <<<"Will it ignore" &&
	"$PASS" insert -e blah3 <<<"case when searching?" &&
	"$PASS" insert -e folder/blah4 <<<"Yes, it does. Wonderful!" &&
	results="$("$PASS" grep -i wonder)" &&
	[[ $(wc -l <<<"$results") -eq 4 ]] &&
	grep -q blah1 <<<"$results" &&
	grep -q blah4 <<<"$results"
'

test_done

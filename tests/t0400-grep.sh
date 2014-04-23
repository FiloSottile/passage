#!/bin/bash

test_description='Grep check'
. ./setup.sh

test_expect_success 'Make sure grep prints normal lines' '
	pass init $KEY1 &&
	pass insert -e blah1 <<<"hello" &&
	pass insert -e blah2 <<<"my name is" &&
	pass insert -e folder/blah3 <<<"I hate computers" &&
	pass insert -e blah4 <<<"me too!" &&
	pass insert -e folder/where/blah5 <<<"They are hell" &&
	results="$(pass grep hell)" &&
	[[ $(wc -l <<<"$results") -eq 4 ]] &&
	grep -q blah5 <<<"$results" &&
	grep -q blah1 <<<"$results" &&
	grep -q "They are" <<<"$results"
'

test_done

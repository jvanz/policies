#!/usr/bin/env bats

@test "Accept a valid request" {
	run kwctl run --raw --request-path test_data/valid.json --settings-path test_data/settings.json annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
 }

@test "Reject invalid request" {
	run kwctl run --raw --request-path test_data/invalid.json --settings-path test_data/settings.json annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
	[ $(expr "$output" : '.*"message":"this request is not accepted".*') -ne 0 ]
 }

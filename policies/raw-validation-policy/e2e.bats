#!/usr/bin/env bats

@test "Accept a valid request" {
	run kwctl run  --request-path test_data/valid.json  annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
 }

@test "Reject invalid request" {
	run kwctl run  --request-path test_data/invalidw.json annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
	[ $(expr "$output" : '.*"message":"pod name invalid-pod-name is not accepted".*') -ne 0 ]
 }

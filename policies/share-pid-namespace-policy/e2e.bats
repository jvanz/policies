#!/usr/bin/env bats

@test "Accept request with no sharing PID namespace configuration" {
	run kwctl run  --request-path test_data/deployment_with_no_sharing_pid_namespace_admission_request.json  annotated-policy.wasm
	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Accept request with no sharing PID namespace configuration set false" {
	run kwctl run  --request-path test_data/deployment_with_sharing_pid_namespace_false_admission_request.json  annotated-policy.wasm
	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Reject deployment admission request with sharing PID namespace configuration set true" {
	run kwctl run  --request-path test_data/deployment_with_sharing_pid_namespace_true_admission_request.json  annotated-policy.wasm
	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
 	[ $(expr "$output" : '.*"message":"pod cannot share host PID namespace".*') -ne 0 ]
}

@test "Reject pod admission request with sharing PID namespace configuration set true" {
	run kwctl run  --request-path test_data/deployment_with_sharing_pid_namespace_true_admission_request.json  annotated-policy.wasm
	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
 	[ $(expr "$output" : '.*"message":"pod cannot share host PID namespace".*') -ne 0 ]
}

#!/usr/bin/env bats

@test "Accept a Deployment without policies specified" {
	run kwctl run --allow-context-aware \
		--raw -r test_data/deployment-no-policy.json \
		--replay-host-capabilities-interactions test_data/replay-session-with-workload-policy.yml \
		annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Accept a Deployment with a policy present" {
	run kwctl run --allow-context-aware \
		--raw -r test_data/deployment-accepted.json \
		--replay-host-capabilities-interactions test_data/replay-session-with-workload-policy.yml \
		annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Reject invalid request" {
	run kwctl run --allow-context-aware \
		--raw -r test_data/deployment-rejected.json \
		--replay-host-capabilities-interactions test_data/replay-session-no-workload-policy.yml \
		annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
}

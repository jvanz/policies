#!/usr/bin/env bats

@test "Accept service with no duplicated service selectors" {
	run kwctl run --allow-context-aware \
		-r test_data/service-admission-request.json \
		--replay-host-capabilities-interactions test_data/replay-session-with-label-selector.yml \
		annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Reject service with duplicated service selector" {
	run kwctl run --allow-context-aware \
		-r test_data/service-admission-request.json \
		--replay-host-capabilities-interactions test_data/replay-session-service-with-app-selector.yml \
		annotated-policy.wasm


	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
	[ $(expr "$output" : '.*"message":"service is using selector(s) already defined by these services.*') -ne 0 ]
}

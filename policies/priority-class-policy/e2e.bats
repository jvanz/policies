#!/usr/bin/env bats

@test "Accept allowed priority class" {
	run kwctl run --request-path test_data/deployment_creation.json --settings-path test_data/settings-allowed-list.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
	[ $(expr "$output" : '.*"patch":.*') -eq 0 ]
}

@test "Accept when allowed priority class list is missing" {
	run kwctl run --request-path test_data/deployment_creation_missing.json --settings-path test_data/settings-allowed-list.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Reject non allowed priority class" {
	run kwctl run --request-path test_data/deployment_creation_invalid.json --settings-path test_data/settings-allowed-list.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
	[ $(expr "$output" : '.*"message":"Priority class \\"critical\\" is not allowed.*') -ne 0 ]
}

@test "Accept denied priority class" {
	run kwctl run --request-path test_data/deployment_creation_invalid.json --settings-path test_data/settings-denied-list.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Accept when denied priority class list is missing" {
	run kwctl run --request-path test_data/deployment_creation_missing.json --settings-path test_data/settings-denied-list.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Reject denied priority class" {
	run kwctl run --request-path test_data/deployment_creation.json --settings-path test_data/settings-denied-list.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
}

@test "Default priority class should be used when PodSpec has no class defined" {
	run kwctl run --request-path test_data/deployment_creation_missing.json --settings-path test_data/settings-allowed-list-with-default-class.json annotated-policy.wasm

	# this prints the output when one the checks below fails
	echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
	[ $(expr "$output" : '.*"patch":.*') -ne 0 ]
}

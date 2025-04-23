#!/usr/bin/env bats

@test "Accept listed priority class" {
	run kwctl run  --request-path test_data/deployment_creation.json --settings-path test_data/settings.json  annotated-policy.wasm

  # this prints the output when one the checks below fails
  echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Accept when priority class is missing" {
	run kwctl run  --request-path test_data/deployment_creation_missing.json --settings-path test_data/settings.json  annotated-policy.wasm

  # this prints the output when one the checks below fails
  echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
}

@test "Reject non listed priority class" {
	run kwctl run  --request-path test_data/deployment_creation_invalid.json --settings-path test_data/settings.json  annotated-policy.wasm

  # this prints the output when one the checks below fails
  echo "output = ${output}"

	[ "$status" -eq 0 ]
	[ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
	[ $(expr "$output" : '.*"message":"Priority class \\"critical\\" is not allowed.*') -ne 0 ]
}

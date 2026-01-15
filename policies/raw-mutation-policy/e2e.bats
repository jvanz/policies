#!/usr/bin/env bats

@test "accept" {
  run kwctl run --raw annotated-policy.wasm --request-path test_data/accept.json --settings-path test_data/settings.json
  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request accepted
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*true') -ne 0 ]
}

@test "mutate" {
  run kwctl run --raw annotated-policy.wasm --request-path test_data/mutate.json --settings-path test_data/settings.json

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request accepted
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*true') -ne 0 ]
  [ $(expr "$output" : '.*"patchType":"JSONPatch"') -ne 0 ]
}

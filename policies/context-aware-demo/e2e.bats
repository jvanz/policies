#!/usr/bin/env bats

@test "Accept and mutate" {
  run kwctl run \
    --request-path test_data/pod_creation_missing_labels.json \
    --allow-context-aware \
    --replay-host-capabilities-interactions test_data/session-namespace-found.yml \
    annotated-policy.wasm

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
  [ $(expr "$output" : '.*JSONPatch.*') -ne 0 ]
}

@test "Accept without mutation" {
  run kwctl run \
    --request-path test_data/pod_creation_all_labels.json \
    --allow-context-aware \
    --replay-host-capabilities-interactions test_data/session-namespace-found.yml \
    annotated-policy.wasm

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
  [ $(expr "$output" : '.*JSONPatch.*') -ne 1 ]
}

@test "Reject invalid name" {
  run kwctl run \
    --request-path test_data/pod_creation_all_labels.json \
    --allow-context-aware \
    --replay-host-capabilities-interactions test_data/session-namespace-not-found.yml \
    annotated-policy.wasm

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
  [ $(expr "$output" : '.*Cannot find v1/Namespace.*') -ne 0 ]
}

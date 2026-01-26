#!/usr/bin/env bats

@test "accept pod with allowed profile (runtime/default)" {
  run kwctl run \
    --request-path test_data/pod_valid.json \
    --settings-json '{"allowed_profiles": ["runtime/default"]}' \
    annotated-policy.wasm

  [ "$status" -eq 0 ]
  [[ "$output" == *"allowed\":true"* ]]
}

@test "accept pod with no profile specified (defaults to safe)" {
  run kwctl run \
    --request-path test_data/pod_no_profile.json \
    --settings-json '{"allowed_profiles": ["runtime/default"]}' \
    annotated-policy.wasm

  [ "$status" -eq 0 ]
  [[ "$output" == *"allowed\":true"* ]]
}

@test "reject pod with unconfined profile" {
  run kwctl run \
    --request-path test_data/pod_invalid.json \
    --settings-json '{"allowed_profiles": ["runtime/default"]}' \
    annotated-policy.wasm

  [ "$status" -eq 0 ]
  [[ "$output" == *"allowed\":false"* ]]
}
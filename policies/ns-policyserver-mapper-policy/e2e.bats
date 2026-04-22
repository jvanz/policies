#!/usr/bin/env bats

@test "Mutate AdmissionPolicy: sets policyServer from namespace label" {
  run kwctl run \
    --request-path test_data/admission_policy_create.json \
    --allow-context-aware \
    --replay-host-capabilities-interactions test_data/session-namespace-with-label.yml \
    annotated-policy.wasm

  # this prints the output when one of the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
  [ $(expr "$output" : '.*"patchType":"JSONPatch".*') -ne 0 ]

  # Verify the patch sets spec.policyServer to the value from the namespace label
  patch=$(echo "${output}" | grep '{.*"patch".*}' | jq -r ".patch" | base64 --decode)
  echo "patch = ${patch}"
  echo "${patch}" | jq -e \
    '[.[] | select(.path == "/spec/policyServer" and .value == "policyserver-team-a")] | length == 1'
}

@test "Mutate AdmissionPolicyGroup: sets policyServer from namespace label" {
  run kwctl run \
    --request-path test_data/admission_policy_group_create.json \
    --allow-context-aware \
    --replay-host-capabilities-interactions test_data/session-namespace-with-label.yml \
    annotated-policy.wasm

  # this prints the output when one of the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
  [ $(expr "$output" : '.*"patchType":"JSONPatch".*') -ne 0 ]

  # Verify the patch sets spec.policyServer to the value from the namespace label
  patch=$(echo "${output}" | grep '{.*"patch".*}' | jq -r ".patch" | base64 --decode)
  echo "patch = ${patch}"
  echo "${patch}" | jq -e \
    '[.[] | select(.path == "/spec/policyServer" and .value == "policyserver-team-a")] | length == 1'
}

@test "Reject AdmissionPolicy: namespace has no policy-server label" {
  run kwctl run \
    --request-path test_data/admission_policy_create_unlabeled_ns.json \
    --allow-context-aware \
    --replay-host-capabilities-interactions test_data/session-namespace-without-label.yml \
    annotated-policy.wasm

  # this prints the output when one of the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*"allowed":false.*') -ne 0 ]
  [ $(expr "$output" : '.*admission.kubewarden.io/policy-server.*') -ne 0 ]
}

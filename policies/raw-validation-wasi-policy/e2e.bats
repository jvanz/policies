#!/usr/bin/env bats

@test "reject because invalid settings" {
  run kwctl run annotated-policy.wasm \
    -r test_data/pod-creation.json \
    --settings-json '{"requiredAnnotations": {"fluxcd.io/cat": "felix"}, "forbiddenAnnotations": ["fluxcd.io/cat"]}'

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 1 ]
  [ $(expr "$output" : '.*valid.*false') -ne 0 ]
  [ $(expr "$output" : ".*The following annotations are.*") -ne 0 ]
}

@test "accept but no mutation" {
  run kwctl run annotated-policy.wasm \
    -r test_data/pod-creation.json \
    --settings-json '{"requiredAnnotations": {"fluxcd.io/cat": "felix"}}'

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request accepted but not mutated
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*true') -ne 0 ]
  [ $(expr "$output" : '.*"patchType":"JSONPatch".*') -eq 0 ]
}

@test "accept and mutate" {
  run kwctl run annotated-policy.wasm \
    -r test_data/pod-creation.json \
    --settings-json '{"requiredAnnotations": {"fluxcd.io/cat": "sylvester"}}'

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request accepted but not mutated
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*true') -ne 0 ]
  [ $(expr "$output" : '.*"patchType":"JSONPatch".*') -ne 0 ]
}

@test "reject because forbidden annotation is being used" {
  run kwctl run annotated-policy.wasm \
    -r test_data/pod-creation.json \
    --settings-json '{"forbiddenAnnotations": ["fluxcd.io/cat"]}'

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request rejected
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*false') -ne 0 ]
}

#!/usr/bin/env bats

@test "Mutate pod definition" {
  # Need to run the command inside of `bash -c` because of a bats
  # limitation: https://bats-core.readthedocs.io/en/stable/gotchas.html?highlight=pipe#my-piped-command-does-not-work-under-run
  run bash -c 'kwctl run \
    --request-path test_data/pod_with_5_ndots.json \
    annotated-policy.wasm 2>/dev/null | jq -er ".patch | @base64d"'

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*{"op":"replace","path":"/spec/dnsConfig/options/0/value","value":"1"}.*') -ne 0 ]
}

@test "Do not mutate Pod definition" {
  # Need to run the command inside of `bash -c` because of a bats
  # limitation: https://bats-core.readthedocs.io/en/stable/gotchas.html?highlight=pipe#my-piped-command-does-not-work-under-run
  run bash -c 'kwctl run \
    --request-path test_data/pod_with_5_ndots.json \
    --settings-path test_data/settings-5-ndots.yaml \
    annotated-policy.wasm 2>/dev/null | jq -er ".patch"'

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  [ "$status" -eq 1 ]
  [ $(expr "$output" : 'null') -ne 0 ]
}

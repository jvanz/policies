#!/usr/bin/env bats

@test "accept if the request is valid" {
  run kwctl run --raw -e opa annotated-policy.wasm -r test_data/valid.json

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request accepted
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*true') -ne 0 ]
}

@test "reject if the request is invalid" {
  run kwctl run --raw -e opa annotated-policy.wasm -r test_data/invalid.json

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request rejected
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*false') -ne 0 ]
  [ $(expr "$output" : '.*User not allowed.*') -ne 0 ]
}

@test "reject if the request has no user field" {
  run kwctl run --raw -e opa annotated-policy.wasm -r test_data/invalid_no_user_field.json

  # this prints the output when one the checks below fails
  echo "output = ${output}"

  # request rejected
  [ "$status" -eq 0 ]
  [ $(expr "$output" : '.*allowed.*false') -ne 0 ]
  [ $(expr "$output" : '.*User not allowed.*') -ne 0 ]
}

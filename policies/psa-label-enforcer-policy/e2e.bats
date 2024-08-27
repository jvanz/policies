#!/usr/bin/env bats

@test "Mutate namespace with no labels" {
	run kwctl run  --request-path test_data/namespace_with_no_labels.json --settings-path test_data/setting_all_modes_set.json annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
	[ $(expr "$output" : '.*"patchType":"JSONPatch".*') -ne 0 ]
 }

@test "Accept namespace with all labels right" {
	run kwctl run  --request-path test_data/namespace_with_labels.json --settings-path test_data/setting_all_modes_set.json annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
	[ $(expr "$output" : '.*"patchType":"JSONPatch".*') -eq 0 ]
 }

@test "Mutate namespace when labels are invalid" {
	run kwctl run  --request-path test_data/namespace_with_invalid_labels.json --settings-path test_data/setting_all_modes_set.json annotated-policy.wasm
	[ "$status" -eq 0 ]
	echo "$output"
	[ $(expr "$output" : '.*"allowed":true.*') -ne 0 ]
	[ $(expr "$output" : '.*"patchType":"JSONPatch".*') -ne 0 ]
 }

@test "Invalid settings should cause an error" {
	run kwctl run  --request-path test_data/namespace_with_invalid_labels.json --settings-path test_data/invalid_settings.json annotated-policy.wasm
	[ "$status" -ne 0 ]
	echo "$output"
	[ $(expr "$output" : '.*Provided settings are not valid.*') -ne 0 ]
}

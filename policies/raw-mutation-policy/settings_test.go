package main

import (
	"testing"

	mapset "github.com/deckarep/golang-set/v2"
)

func TestValidateSettingsAccept(t *testing.T) {
	settings := &Settings{
		ForbiddenResources: mapset.NewSet("banana"),
		DefaultResource:    "hay",
	}

	valid, err := settings.Valid()
	if !valid {
		t.Errorf("Settings are reported as not valid")
	}
	if err != nil {
		t.Errorf("Unexpected error %+v", err)
	}
}

func TestValidateSettingsRejectDefaultResourceEmpty(t *testing.T) {
	settings := &Settings{
		ForbiddenResources: mapset.NewSet("banana"),
		DefaultResource:    "",
	}

	valid, err := settings.Valid()
	if valid {
		t.Errorf("Settings are reported as valid")
	}

	if err == nil {
		t.Errorf("Unexpected nil error")
	}
}

func TestValidateSettingsRejectDefaultResourceForbidden(t *testing.T) {
	settings := &Settings{
		ForbiddenResources: mapset.NewSet("banana"),
		DefaultResource:    "banana",
	}

	valid, err := settings.Valid()
	if valid {
		t.Errorf("Settings are reported as valid")
	}

	if err == nil {
		t.Errorf("Unexpected nil error")
	}
}

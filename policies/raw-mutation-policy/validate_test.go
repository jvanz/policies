package main

import (
	"encoding/json"
	"testing"

	kubewarden_protocol "github.com/kubewarden/policy-sdk-go/protocol"
)

func TestMutation(t *testing.T) {
	request := Request{
		User:     "tonio",
		Action:   "eats",
		Resource: "banana",
	}

	payload, err := json.Marshal(RawValidationRequest{
		Request: request,
	})
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	responsePayload, err := validate(payload)
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	var response kubewarden_protocol.ValidationResponse
	if err := json.Unmarshal(responsePayload, &response); err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	if response.Accepted != true {
		t.Error("Unexpected rejection")
	}

	if response.MutatedObject == nil {
		t.Error("Unexpected mutation")
	}

	mutatedRequestJSON, err := json.Marshal(response.MutatedObject.(map[string]interface{}))
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	if err := json.Unmarshal(mutatedRequestJSON, &request); err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	if request.Resource != "hay" {
		t.Errorf("Unexpected mutation: %+v", response.MutatedObject)
	}
}

func TestAcceptWithoutMutation(t *testing.T) {
	request := Request{
		User:     "tonio",
		Action:   "eats",
		Resource: "spinach",
	}

	payload, err := json.Marshal(RawValidationRequest{
		Request: request,
	})
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	responsePayload, err := validate(payload)
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	var response kubewarden_protocol.ValidationResponse
	if err := json.Unmarshal(responsePayload, &response); err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	if !response.Accepted {
		t.Error("Unexpected rejection")
	}

	if response.MutatedObject != nil {
		t.Error("Unexpected mutation")
	}
}

func TestRejectInvalidPayload(t *testing.T) {
	payload := []byte(`{"foo": "bar"}`)

	responsePayload, err := validate(payload)
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	var response kubewarden_protocol.ValidationResponse
	if err := json.Unmarshal(responsePayload, &response); err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}

	if response.Accepted {
		t.Error("Unexpected acceptance")
	}

	if *response.Code != 400 {
		t.Errorf("Unexpected status code")
	}
}

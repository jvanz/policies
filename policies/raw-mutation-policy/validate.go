package main

import (
	"encoding/json"
	"strings"

	onelog "github.com/francoispqt/onelog"
	kubewarden "github.com/kubewarden/policy-sdk-go"
)

func validate(payload []byte) ([]byte, error) {
	decoder := json.NewDecoder(strings.NewReader(string(payload)))
	decoder.DisallowUnknownFields()

	validationRequest := RawValidationRequest{}
	err := decoder.Decode(&validationRequest)
	if err != nil {
		return kubewarden.RejectRequest(
			kubewarden.Message(err.Error()),
			kubewarden.Code(400))
	}

	request := validationRequest.Request

	logger.DebugWithFields("validating request", func(e onelog.Entry) {
		e.String("user", request.User)
		e.String("action", request.Action)
		e.String("resource", request.Resource)
	})

	if request.Action == "eats" && request.Resource == "banana" {
		request.Resource = "hay"
		return kubewarden.MutateRequest(request)
	}

	return kubewarden.AcceptRequest()
}

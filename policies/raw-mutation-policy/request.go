package main

type RawValidationRequest struct {
	Request Request `json:"request"`
	// This policy does not require any settings.
	// The field definition is still needed
	// since we are using a decoder with DisallowUnknownFields set.
	Settings Settings `json:"settings"`
}

type Request struct {
	User     string `json:"user"`
	Action   string `json:"action"`
	Resource string `json:"resource"`
}

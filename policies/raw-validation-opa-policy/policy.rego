package validation

deny[msg] {
    not input.request.user == "tonio"
	msg := "User not allowed"
}

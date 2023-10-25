package policy

import data.validation

main = {
	"response": response,
}

default uid = ""

uid = input.request.uid

response = {
	"uid": uid,
	"allowed": false,
	"status": {"message": reason},
} {
	reason = concat(", ", validation.deny)
	reason != ""
} else = {
	"uid": uid,
	"allowed": true,
} {
	true
}

package validation

valid_request = {"request": {"user": "tonio", "action": "eats", "resource": "hay"}}

invalid_request = {"request": {"user": "wanda", "action": "eats", "resource": "banana"}}

test_accept { 
    res = deny with input as valid_request
	count(res) = 0
}

test_reject {
	res = deny with input as invalid_request
	count(res) = 1
}

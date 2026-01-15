package policy

review_ingress_unique = {"review": {
	"kind": {
		"group": "networking.k8s.io",
		"version": "v1",
		"kind": "Ingress",
	},
	"object": {
		"metadata": {
			"namespace": "default",
			"name": "test",
		},
		"spec": {"rules": [{"host": "esempio.it"}]},
	},
}}

review_ingress_duplicate = {"review": {
	"kind": {
		"group": "networking.k8s.io",
		"kind": "Ingress",
		"version": "v1",
	},
	"object": {
		"metadata": {
			"namespace": "default",
			"name": "test",
		},
		"spec": {"rules": [{"host": "example.com"}]},
	},
}}

inventory = {"namespace": {"tenant-a": {"networking.k8s.io/v1": {"Ingress": {"tenant-a-ingress": {
	"metadata": {
		"name": "tenant-a-ingress",
		"namespace": "tenant-a",
	},
	"spec": {"rules": [{"host": "example.com"}]},
}}}}}}

test_accept {
	r = review_ingress_unique
	res = violation with input as r
		with data.inventory as inventory
	count(res) = 0
}

test_reject {
	r = review_ingress_duplicate
	res = violation with input as r
		with data.inventory as inventory
	count(res) = 1
}

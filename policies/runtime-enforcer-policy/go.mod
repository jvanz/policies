module github.com/kubewarden/container-resources-policy

go 1.25.8

require (
	github.com/francoispqt/onelog v0.0.0-20190306043706-8c2bb31b10a4
	github.com/kubewarden/k8s-objects v1.29.0-kw1
	github.com/kubewarden/policy-sdk-go v0.13.1
	github.com/stretchr/testify v1.11.1
	github.com/wapc/wapc-guest-tinygo v0.3.3
)

require (
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/francoispqt/gojay v0.0.0-20181220093123-f2cc13a668ca // indirect
	github.com/go-openapi/strfmt v0.21.3 // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace (
	github.com/go-openapi/strfmt => github.com/kubewarden/strfmt v0.1.3
	github.com/rancher-sandbox/runtime-enforcer => github.com/holyspectral/runtime-enforcer v0.0.0-20260331010021-7be1fade743a
)

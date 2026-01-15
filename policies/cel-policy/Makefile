SOURCE_FILES := $(shell find . -type f -name '*.go')
VERSION ?= $(shell git describe | cut -c2-)

E2E_TEST_ANNONATION_METADATA ?= "test_data/annotation-metadata.yml"

policy.wasm: $(SOURCE_FILES) go.mod go.sum
	GOOS=wasip1 GOARCH=wasm go build -gcflags=all="-l -B -wb=false" -ldflags="-w -s" -o policy.wasm
	wasm-opt --enable-bulk-memory -Oz -o policy.wasm policy.wasm 


annotated-policy.wasm: policy.wasm metadata.yml
	kwctl annotate -m metadata.yml -u README.md -o annotated-policy.wasm policy.wasm

.PHONY: lint
lint:
	go vet ./...
	golangci-lint run

.PHONY: lint-fix
lint-fix:
	golangci-lint run --fix

.PHONY: fmt
fmt:
	go fmt ./...

.PHONY: test
test:
	go test -v ./...

.PHONY: clean
clean:
	go clean
	rm -f policy.wasm annotated-policy.wasm

.PHONY: e2e-tests
e2e-tests: policy.wasm
	# The policy annonation uses a different metadata file for testing because the 
	# e2e tests require access to ConfigMap to test the parameters feature.
	yq eval-all 'select(fileIndex == 0) *+? select(fileIndex == 1)' metadata.yml test_data/metadata.yml > $(E2E_TEST_ANNONATION_METADATA)
	kwctl annotate -m $(E2E_TEST_ANNONATION_METADATA) -u README.md -o annotated-policy.wasm policy.wasm
	bats e2e.bats

KUBE_API_VERSION?=1.32

.PHONY: build
build:
	K8S_OPENAPI_ENABLED_VERSION=$(KUBE_API_VERSION) cargo build --release

.PHONY: fmt
fmt:
	K8S_OPENAPI_ENABLED_VERSION=$(KUBE_API_VERSION) cargo fmt --all -- --check

.PHONY: lint
lint:
	K8S_OPENAPI_ENABLED_VERSION=$(KUBE_API_VERSION) cargo clippy --no-default-features --features "annotations" -- -D warnings

.PHONY: check
check:
	@for feature in $$(cargo read-manifest --manifest-path Cargo.toml | jq -r '.features | keys[]'); do \
		K8S_OPENAPI_ENABLED_VERSION=$(KUBE_API_VERSION) cargo check --no-default-features --features "$$feature"; \
	done
	
.PHONY: typos
typos:
	# run typo checker from crate-ci/typos
	typos $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: test
test: fmt lint
	cargo test 

.PHONY: clean
clean:
	cargo clean

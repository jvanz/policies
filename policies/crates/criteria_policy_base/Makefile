.PHONY: build
build:
	cargo build --release

.PHONY: fmt
fmt:
	cargo fmt --all -- --check

.PHONY: lint
lint:
	cargo clippy --no-default-features --features "annotations" -- -D warnings

.PHONY: check
check:
	@for feature in $$(cargo read-manifest --manifest-path Cargo.toml | jq -r '.features | keys[]'); do \
		cargo check --no-default-features --features "$$feature"; \
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

.PHONY: build
build:
	cargo build --release

.PHONY: fmt
fmt:
	cargo fmt --all -- --check

.PHONY: lint
lint:
	cargo clippy -- -D warnings

.PHONY: check
check:
	cargo check 
	
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

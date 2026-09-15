.PHONY: clean annotated-policy.wasm test test-rust test-go test-shell lint lint-rust lint-go lint-shell e2e-tests e2e-tests-rust e2e-tests-go

# The release tooling in hack/. It decides the version of every policy, so it
# is checked and tested like any other code.
#
# hack/release-all-policies.sh is left out: it predates this target and carries
# a shellcheck warning of its own. Add it here once that is dealt with.
SHELL_SCRIPTS := hack/policy-release-notes.sh hack/lib/conventional-commit.sh

# Helper function to run a target across all policies (excluding crates/) with summary
define run-policy-target
	@passed=0; failed=0; failed_policies=""; \
	for policy in policies/*/; do \
		[ "$$policy" = "policies/crates/" ] && continue; \
		if [ -f "$$policy/Makefile" ]; then \
			echo "Running $(1) in $$policy"; \
			if $(MAKE) -C "$$policy" $(1); then \
				passed=$$((passed + 1)); \
			else \
				failed=$$((failed + 1)); \
				failed_policies="$$failed_policies  - $$policy\n"; \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "=== $(1) Summary ==="; \
	echo "Passed: $$passed"; \
	echo "Failed: $$failed"; \
	if [ $$failed -gt 0 ]; then \
		echo ""; \
		echo "Failed policies:"; \
		printf "$$failed_policies"; \
		exit 1; \
	fi
endef

# Helper function to run a target across all crates
define run-crate-target
	@for crate in policies/crates/*/; do \
		if [ -f "$$crate/Makefile" ]; then \
			echo "Running $(1) in $$crate"; \
			$(MAKE) -C "$$crate" $(1); \
		fi; \
	done
endef

# Helper function to run a target across Rust policies only (excluding crates/) with summary
define run-rust-policy-target
	@passed=0; failed=0; failed_policies=""; \
	for policy in policies/*/; do \
		[ "$$policy" = "policies/crates/" ] && continue; \
		if [ -f "$$policy/Makefile" ] && [ -f "$$policy/Cargo.toml" ]; then \
			echo "Running $(1) in $$policy"; \
			if $(MAKE) -C "$$policy" $(1); then \
				passed=$$((passed + 1)); \
			else \
				failed=$$((failed + 1)); \
				failed_policies="$$failed_policies  - $$policy\n"; \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "=== $(1) Summary ==="; \
	echo "Passed: $$passed"; \
	echo "Failed: $$failed"; \
	if [ $$failed -gt 0 ]; then \
		echo ""; \
		echo "Failed policies:"; \
		printf "$$failed_policies"; \
		exit 1; \
	fi
endef

# Helper function to run a target across Go policies only (excluding crates/) with summary
define run-go-policy-target
	@passed=0; failed=0; failed_policies=""; \
	for policy in policies/*/; do \
		[ "$$policy" = "policies/crates/" ] && continue; \
		if [ -f "$$policy/Makefile" ] && [ -f "$$policy/go.mod" ]; then \
			echo "Running $(1) in $$policy"; \
			if $(MAKE) -C "$$policy" $(1); then \
				passed=$$((passed + 1)); \
			else \
				failed=$$((failed + 1)); \
				failed_policies="$$failed_policies  - $$policy\n"; \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "=== $(1) Summary ==="; \
	echo "Passed: $$passed"; \
	echo "Failed: $$failed"; \
	if [ $$failed -gt 0 ]; then \
		echo ""; \
		echo "Failed policies:"; \
		printf "$$failed_policies"; \
		exit 1; \
	fi
endef

clean:
	$(call run-policy-target,clean)
	$(call run-crate-target,clean)

annotated-policy.wasm:
	$(call run-policy-target,annotated-policy.wasm)

test:
	$(call run-policy-target,test)
	$(call run-crate-target,test)

# Unit tests for the release tooling in hack/. Needs bats.
test-shell:
	bats hack/tests/

lint-shell:
	shellcheck -x $(SHELL_SCRIPTS)

test-rust:
	$(call run-rust-policy-target,test)
	$(call run-crate-target,test)

test-go:
	$(call run-go-policy-target,test)

lint:
	$(call run-policy-target,lint)
	$(call run-crate-target,lint)

lint-rust:
	$(call run-rust-policy-target,lint)
	$(call run-crate-target,lint)

lint-go:
	$(call run-go-policy-target,lint)

e2e-tests:
	$(call run-policy-target,e2e-tests)

e2e-tests-rust:
	$(call run-rust-policy-target,e2e-tests)

e2e-tests-go:
	$(call run-go-policy-target,e2e-tests)

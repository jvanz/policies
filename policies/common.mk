# Targets shared by every policy language Makefile (Makefile.rust,
# Makefile.wasigo, Makefile.tinygo, Makefile.p-rego). Included at the end of
# each of those files, mirroring the ../go-common.mk convention used by the
# Go-based ones.
#
# New variables only: this file must not redefine ROOT_DIR or POLICY_DIR,
# both of which are already (if inconsistently) defined by some of the
# per-language Makefiles.
POLICY_BASENAME := $(notdir $(patsubst %/,%,$(CURDIR)))
REPO_ROOT := $(realpath $(CURDIR)/../..)

.PHONY: check-hauler-manifest
check-hauler-manifest:
	@$(REPO_ROOT)/hack/check-hauler-manifest.sh $(CURDIR)

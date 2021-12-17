PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib

PLATFORMFILE := src/platform/$(shell uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh

BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
FISHCOMPDIR ?= $(PREFIX)/share/fish/vendor_completions.d

ifneq ($(WITH_ALLCOMP),)
WITH_BASHCOMP := $(WITH_ALLCOMP)
WITH_ZSHCOMP := $(WITH_ALLCOMP)
WITH_FISHCOMP := $(WITH_ALLCOMP)
endif
ifeq ($(WITH_BASHCOMP),)
ifneq ($(strip $(wildcard $(BASHCOMPDIR))),)
WITH_BASHCOMP := yes
endif
endif
ifeq ($(WITH_ZSHCOMP),)
ifneq ($(strip $(wildcard $(ZSHCOMPDIR))),)
WITH_ZSHCOMP := yes
endif
endif
ifeq ($(WITH_FISHCOMP),)
ifneq ($(strip $(wildcard $(FISHCOMPDIR))),)
WITH_FISHCOMP := yes
endif
endif

all:
	@echo "Passage is a shell script, so there is nothing to do. Try \"make install\" instead."

install-common:
	@[ "$(WITH_BASHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 -v src/completion/pass.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/passage"
	@[ "$(WITH_ZSHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(ZSHCOMPDIR)" && install -m 0644 -v src/completion/pass.zsh-completion "$(DESTDIR)$(ZSHCOMPDIR)/_passage"
	@[ "$(WITH_FISHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(FISHCOMPDIR)" && install -m 0644 -v src/completion/pass.fish-completion "$(DESTDIR)$(FISHCOMPDIR)/passage.fish"


ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/passage" && install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/passage/platform.sh"
	@install -v -d "$(DESTDIR)$(LIBDIR)/passage/extensions"
	@install -v -d "$(DESTDIR)$(BINDIR)/"
	@trap 'rm -f src/.passage' EXIT; sed 's:.*PLATFORM_FUNCTION_FILE.*:source "$(LIBDIR)/passage/platform.sh":;s:^SYSTEM_EXTENSION_DIR=.*:SYSTEM_EXTENSION_DIR="$(LIBDIR)/passage/extensions":' src/password-store.sh > src/.passage && \
	install -v -d "$(DESTDIR)$(BINDIR)/" && install -m 0755 -v src/.passage "$(DESTDIR)$(BINDIR)/passage"
else
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/passage/extensions"
	@trap 'rm -f src/.passage' EXIT; sed '/PLATFORM_FUNCTION_FILE/d;s:^SYSTEM_EXTENSION_DIR=.*:SYSTEM_EXTENSION_DIR="$(LIBDIR)/passage/extensions":' src/password-store.sh > src/.passage && \
	install -v -d "$(DESTDIR)$(BINDIR)/" && install -m 0755 -v src/.passage "$(DESTDIR)$(BINDIR)/passage"
endif

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(BINDIR)/passage" \
		"$(DESTDIR)$(LIBDIR)/passage" \
		"$(DESTDIR)$(BASHCOMPDIR)/passage" \
		"$(DESTDIR)$(ZSHCOMPDIR)/_passage" \
		"$(DESTDIR)$(FISHCOMPDIR)/passage.fish"

.PHONY: install uninstall install-common clean

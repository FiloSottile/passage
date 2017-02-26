PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man

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
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install-common:
	@install -v -d "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 -v man/pass.1 "$(DESTDIR)$(MANDIR)/man1/pass.1"
	@[ "$(WITH_BASHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 -v src/completion/pass.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/pass"
	@[ "$(WITH_ZSHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(ZSHCOMPDIR)" && install -m 0644 -v src/completion/pass.zsh-completion "$(DESTDIR)$(ZSHCOMPDIR)/_pass"
	@[ "$(WITH_FISHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(FISHCOMPDIR)" && install -m 0644 -v src/completion/pass.fish-completion "$(DESTDIR)$(FISHCOMPDIR)/pass.fish"


ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/password-store" && install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/password-store/platform.sh"
	@install -v -d "$(DESTDIR)$(LIBDIR)/password-store/extensions"
	@install -v -d "$(DESTDIR)$(BINDIR)/"
	@trap 'rm -f src/.pass' EXIT; sed 's:.*PLATFORM_FUNCTION_FILE.*:source "$(LIBDIR)/password-store/platform.sh":;s:^SYSTEM_EXTENSION_DIR=.*:SYSTEM_EXTENSION_DIR="$(LIBDIR)/password-store/extensions":' src/password-store.sh > src/.pass && \
	install -v -d "$(DESTDIR)$(BINDIR)/" && install -m 0755 -v src/.pass "$(DESTDIR)$(BINDIR)/pass"
else
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/password-store/extensions"
	@trap 'rm -f src/.pass' EXIT; sed '/PLATFORM_FUNCTION_FILE/d;s:^SYSTEM_EXTENSION_DIR=.*:SYSTEM_EXTENSION_DIR="$(LIBDIR)/password-store/extensions":' src/password-store.sh > src/.pass && \
	install -v -d "$(DESTDIR)$(BINDIR)/" && install -m 0755 -v src/.pass "$(DESTDIR)$(BINDIR)/pass"
endif

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(BINDIR)/pass" \
		"$(DESTDIR)$(LIBDIR)/password-store" \
		"$(DESTDIR)$(MANDIR)/man1/pass.1" \
		"$(DESTDIR)$(BASHCOMPDIR)/pass" \
		"$(DESTDIR)$(ZSHCOMPDIR)/_pass" \
		"$(DESTDIR)$(FISHCOMPDIR)/pass.fish"

TESTS = $(sort $(wildcard tests/t[0-9][0-9][0-9][0-9]-*.sh))

test: $(TESTS)

$(TESTS):
	@$@ $(PASS_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/ tests/gnupg/random_seed

.PHONY: install uninstall install-common test clean $(TESTS)

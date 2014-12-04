PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man

PLATFORMFILE := src/platform/$(shell uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh

BASHCOMP_PATH ?= $(DESTDIR)$(PREFIX)/share/bash-completion/completions
ZSHCOMP_PATH ?= $(DESTDIR)$(PREFIX)/share/zsh/site-functions
FISHCOMP_PATH ?= $(DESTDIR)$(PREFIX)/share/fish/vendor_completions.d

ifeq ($(FORCE_ALL),1)
FORCE_BASHCOMP := 1
FORCE_ZSHCOMP := 1
FORCE_FISHCOMP := 1
endif
ifneq ($(strip $(wildcard $(BASHCOMP_PATH))),)
FORCE_BASHCOMP := 1
endif
ifneq ($(strip $(wildcard $(ZSHCOMP_PATH))),)
FORCE_ZSHCOMP := 1
endif
ifneq ($(strip $(wildcard $(FISHCOMP_PATH))),)
FORCE_FISHCOMP := 1
endif

all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install-common:
	@install -v -d "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 -v man/pass.1 "$(DESTDIR)$(MANDIR)/man1/pass.1"

	@[ "$(FORCE_BASHCOMP)" = "1" ] && install -v -d "$(BASHCOMP_PATH)" && install -m 0644 -v src/completion/pass.bash-completion "$(BASHCOMP_PATH)/pass" || true
	@[ "$(FORCE_ZSHCOMP)" = "1" ] && install -v -d "$(ZSHCOMP_PATH)" && install -m 0644 -v src/completion/pass.zsh-completion "$(ZSHCOMP_PATH)/_pass" || true
	@[ "$(FORCE_FISHCOMP)" = "1" ] && install -v -d "$(FISHCOMP_PATH)" && install -m 0644 -v src/completion/pass.fish-completion "$(FISHCOMP_PATH)/pass.fish" || true


ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/password-store" && install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/password-store/platform.sh"
	@install -v -d "$(DESTDIR)$(BINDIR)/"
	sed 's:.*PLATFORM_FUNCTION_FILE.*:source "$(DESTDIR)$(LIBDIR)/password-store/platform.sh":' src/password-store.sh > "$(DESTDIR)$(BINDIR)/pass"
	@chmod 0755 "$(DESTDIR)$(BINDIR)/pass"
else
install: install-common
	@install -v -d "$(DESTDIR)$(BINDIR)/"
	sed '/PLATFORM_FUNCTION_FILE/d' src/password-store.sh > "$(DESTDIR)$(BINDIR)/pass"
	@chmod 0755 "$(DESTDIR)$(BINDIR)/pass"
endif

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(BINDIR)/pass" \
		"$(DESTDIR)$(LIBDIR)/password-store/" \
		"$(DESTDIR)$(MANDIR)/man1/pass.1" \
		"$(BASHCOMP_PATH)/pass" \
		"$(ZSHCOMP_PATH)/_pass" \
		"$(FISHCOMP_PATH)/pass.fish"
	@rmdir "$(DESTDIR)$(LIBDIR)/password-store/" 2>/dev/null || true

TESTS = $(sort $(wildcard tests/t[0-9][0-9][0-9][0-9]-*.sh))

test: $(TESTS)

$(TESTS):
	@$@ $(PASS_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/ tests/gnupg/random_seed

.PHONY: install uninstall install-common test clean $(TESTS)

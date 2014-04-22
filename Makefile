PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man

PLATFORMFILE := src/platform/$(shell uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh

ifeq ($(FORCE_BASHCOMP),1)
BASHCOMP_SWITCH := "-D"
else
BASHCOMP_SWITCH := 
endif
ifeq ($(FORCE_ZSHCOMP),1)
ZSHCOMP_SWITCH := "-D"
else
ZSHCOMP_SWITCH := 
endif
ifeq ($(FORCE_FISHCOMP),1)
FISHCOMP_SWITCH := "-D"
else
FISHCOMP_SWITCH := 
endif

all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install-common:
	@install -m 0644 -v -D  man/pass.1 "$(DESTDIR)$(MANDIR)/man1/pass.1"
	
	@install -m 0644 -v $(BASHCOMP_SWITCH) src/completion/pass.bash-completion "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/pass" 2>/dev/null || echo "** Bash completion file skipped. **"
	@install -m 0644 -v $(ZSHCOMP_SWITCH) src/completion/pass.zsh-completion "$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_pass" 2>/dev/null || echo "** Zsh completion file skipped. **"
	@install -m 0644 -v $(FISHCOMP_SWITCH) src/completion/pass.fish-completion "$(DESTDIR)$(PREFIX)/share/fish/completions/pass.fish" 2>/dev/null || echo "** Fish completion file skipped. **"

ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-common
	@install -m 0644 -v -D "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/password-store/platform.sh"
	@mkdir -p -v "$(DESTDIR)$(BINDIR)/"
	sed 's:.*PLATFORM_FUNCTION_FILE.*:source "$(DESTDIR)$(LIBDIR)/password-store/platform.sh":' src/password-store.sh > "$(DESTDIR)$(BINDIR)/pass"
	@chmod 0755 "$(DESTDIR)$(BINDIR)/pass"
else
install: install-common
	@mkdir -p -v "$(DESTDIR)$(BINDIR)/"
	sed '/PLATFORM_FUNCTION_FILE/d' src/password-store.sh > "$(DESTDIR)$(BINDIR)/pass"
	@chmod 0755 "$(DESTDIR)$(BINDIR)/pass"
endif

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(BINDIR)/pass" \
		"$(DESTDIR)$(LIBDIR)/password-store/" \
		"$(DESTDIR)$(MANDIR)/man1/pass.1" \
		"$(DESTDIR)$(PREFIX)/share/bash-completion/completions/pass" \
		"$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_pass" \
		"$(DESTDIR)$(PREFIX)/share/fish/completions/pass.fish"

TESTS = $(wildcard tests/t[0-9][0-9][0-9][0-9]-*.sh)

test: $(TESTS)

$(TESTS):
	@cd $$(dirname "$@") && ./$$(basename "$@") $(PASS_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/

.PHONY: install uninstall install-common test clean $(TESTS)

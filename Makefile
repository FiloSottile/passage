PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man

PLATFORMFILE := src/platform/$(shell uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh

.PHONY: install uninstall install-common

all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install-common:
	@mkdir -p "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(LIBDIR)" "$(DESTDIR)$(MANDIR)/man1" "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/"
	@install -m 0644 -v man/pass.1 "$(DESTDIR)$(MANDIR)/man1/pass.1"
	@install -m 0644 -v src/completion/pass.bash-completion "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/pass"

#	Uncomment to install the zsh completion file.
#	@install -m 0644 -v src/completion/pass.zsh-completion "$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_pass"
#
#	Uncomment to install the fish completion file.
#	@install -m 0644 -v src/completion/pass.fish-completion "$(DESTDIR)$(PREFIX)/share/fish/completions/pass.fish"

ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-common
	@install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/password-store.platform.sh"
	@mkdir -p -v "$(DESTDIR)$(BINDIR)/"
	sed 's:.*platform-defined-functions.*:source $(DESTDIR)$(LIBDIR)/password-store.platform.sh:' src/password-store.sh > "$(DESTDIR)$(BINDIR)/pass"
	@chmod 0755 "$(DESTDIR)$(BINDIR)/pass"
else
install: install-common
	@install -m 0755 -v src/password-store.sh "$(DESTDIR)$(BINDIR)/pass"
endif

uninstall:
	@rm -vf "$(DESTDIR)$(BINDIR)/pass" "$(DESTDIR)$(MANDIR)/man1/pass.1" "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/password-store" "$(DESTDIR)$(LIBDIR)/password-store.platform.sh"

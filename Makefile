PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man

PLATFORMFILE := src/platform/$(shell uname | tr '[:upper:]' '[:lower:]').sh

.PHONY: install uninstall install-pass

all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install-pass:
	@mkdir -p "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(LIBDIR)" "$(DESTDIR)$(MANDIR)/man1" "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/"
	@install -m 0755 -v src/password-store.sh "$(DESTDIR)$(BINDIR)/pass"
	@install -m 0644 -v man/pass.1 "$(DESTDIR)$(MANDIR)/man1/pass.1"
	@install -m 0644 -v src/completion/pass.bash-completion "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/password-store"

#	Uncomment to install the zsh completion file.
#	@install -m 0644 -v src/completion/pass.zsh-completion "$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_pass"
#
#	Uncomment to install the fish completion file.
#	@install -m 0644 -v src/completion/pass.fish-completion "$(DESTDIR)$(PREFIX)/share/fish/completions/pass.fish"

ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-pass
	@install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/password-store.platform.sh"
#	The -i "" doesn't work on GNU, where the extra argument isn't needed. Fortuantely, platform file is for non-GNU only.
	sed -i "" 's:.*platform-defined-functions.*:source $(DESTDIR)$(LIBDIR)/password-store.platform.sh:' "$(DESTDIR)$(BINDIR)/pass"
else
install: install-pass
endif

uninstall:
	@rm -vf "$(DESTDIR)$(BINDIR)/pass" "$(DESTDIR)$(MANDIR)/man1/pass.1" "$(DESTDIR)$(PREFIX)/share/bash-completion/completions/password-store" "$(DESTDIR)$(LIBDIR)/password-store.platform.sh"

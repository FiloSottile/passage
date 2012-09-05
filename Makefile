PREFIX ?= /usr
DESTDIR ?=

.PHONY: install

all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install:
	@mkdir -p $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/man/man1 $(DESTDIR)/etc/bash_completion.d
	@install -v src/password-store.sh $(DESTDIR)$(PREFIX)/bin/pass
	@install -v man/pass.1 $(DESTDIR)$(PREFIX)/share/man/man1/pass.1
	@install -v bash-completion/pass-bash-completion.sh $(DESTDIR)/etc/bash_completion.d/password-store

uninstall:
	@rm -vf $(DESTDIR)$(PREFIX)/bin/pass $(DESTDIR)$(PREFIX)/share/man/man1/pass.1 $(DESTDIR)/etc/bash_completion.d/password-store

PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
SYSCONFDIR ?= /etc

.PHONY: install

all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install:
	@mkdir -p $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1 $(DESTDIR)$(SYSCONFDIR)/bash_completion.d
	@install -m 0755 -v src/password-store.sh $(DESTDIR)$(BINDIR)/pass
	@install -m 0644 -v man/pass.1 $(DESTDIR)$(MANDIR)/man1/pass.1
	@install -m 0644 -v bash-completion/pass-bash-completion.sh $(DESTDIR)$(SYSCONFDIR)/bash_completion.d/password-store

uninstall:
	@rm -vf $(DESTDIR)$(BINDIR)/pass $(DESTDIR)$(MANDIR)/man1/pass.1 $(DESTDIR)$(SYSCONFDIR)/bash_completion.d/password-store

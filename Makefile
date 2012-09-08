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
	@install -m 0644 -v contrib/pass.bash-completion $(DESTDIR)$(SYSCONFDIR)/bash_completion.d/password-store
#	Uncomment to install the zsh completion file too.
#	@install -m 0644 -v contrib/pass.zsh-completion $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_pass

uninstall:
	@rm -vf $(DESTDIR)$(BINDIR)/pass $(DESTDIR)$(MANDIR)/man1/pass.1 $(DESTDIR)$(SYSCONFDIR)/bash_completion.d/password-store

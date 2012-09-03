all:
	@echo "Password store is a shell script, so there is nothing to do. Try \"make install\" instead."

install:
	@install -v src/password-store.sh /usr/bin/pass
	@install -v man/pass.1 /usr/share/man/man1/pass.1
	@install -v bash-completion/pass-bash-completion.sh /usr/share/bash-completion/pass

uninstall:
	@rm -vf /usr/bin/pass /usr/share/man/man1/pass.1 /usr/share/bash-completion/pass

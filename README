passage
=======

passage is a fork of password-store (https://www.passwordstore.org) that uses
age (https://age-encryption.org) as a backend instead of GnuPG.

Differences from pass
---------------------

The password store is at $HOME/.passage/store by default.

For decryption, the age identities at $HOME/.passage/identities are used with
the -i age CLI option.

For encryption, the nearest .age-recipients file (that is, the one in the same
directory as the secret, or in the closest parent) is used with the -R age CLI
option. If no .age-recipients files are found, the identities file is used with
the -i option.

Extensions are searched at $HOME/.passage/store. password-store extensions that
wish to be compatible with passage can switch on the PASSAGE variable.

The init command is not currently available, and moving or copying a secret
always re-encrypts it.

Example: simple set up
----------------------

In this setup, the key is simply saved on disk, which can be useful if the
password store is synced to a location less trusted than the local disk.

    age-keygen >> $HOME/.passage/identities

Example: set up with a password-protected key
---------------------------------------------

This setup allows using the identity file password as the primary password
to unlock the store.

    KEY="$(age-keygen)"
    echo "$KEY" | age -p -a >> $HOME/.passage/identities
    echo "$KEY" | age-keygen -y >> $HOME/.passage/store/.age-recipients

Example: set up with rage and age-plugin-yubikey
------------------------------------------------

This setup uses rage (https://github.com/str4d/rage), since age v1.0.0 does
not support plugins yet, and the PIV plugin age-plugin-yubikey
(https://github.com/str4d/age-plugin-yubikey).

It's recommended to add more YubiKeys and/or age keys to the .age-recipients
file as recovery options, in case this YubiKey is lost.

    export PASSAGE_AGE=rage
    age-plugin-yubikey # run interactive setup
    age-plugin-yubikey --identity >> $HOME/.passage/identities
    age-plugin-yubikey --list >> $HOME/.passage/store/.age-recipients

Integrating with fzf
--------------------

The following script can be invoked with any (or no) passage flags, and
spawns a fuzzy search dialog using fzf (https://github.com/junegunn/fzf)
for selecting the secret.

    #! /usr/bin/env bash
    set -eou pipefail
    PREFIX="${PASSAGE_DIR:-$HOME/.passage/store}"
    FZF_DEFAULT_OPTS=""
    name="$(find "$PREFIX" -type f -name '*.age' | \
      sed -e "s|$PREFIX/||" -e 's|\.age$||' | \
      fzf --height 40% --reverse --no-multi)"
    passage "${@}" "$name"

Migrating from pass
-------------------

    #! /usr/bin/env bash
    set -eou pipefail
    cd "${PASSWORD_STORE_DIR:-$HOME/.password-store}"
    while read -r -d "" passfile; do
      name="${passfile#./}"; name="${name%.gpg}"
      [[ -f "${PASSAGE_DIR:-$HOME/.passage/store}/$name.age" ]] && continue
      pass "$name" | passage insert -m "$name" || { passage rm "$name"; break; }
    done < <(find . -path '*/.git' -prune -o -iname '*.gpg' -print0)

Environment variables
---------------------

  PASSAGE_DIR               Password store location

  PASSAGE_IDENTITIES_FILE   Identities file location

  PASSAGE_AGE               age binary (tested with age and rage)

  PASSAGE_RECIPIENTS_FILE   Override recipients for encryption operations
                            Passed to age with -R

  PASSAGE_RECIPIENTS        Override recipients for encryption operations
                            Space separated, each passed to age with -r

All other environment variables from password-store are respected, such as
PASSWORD_STORE_CLIP_TIME and PASSWORD_STORE_GENERATED_LENGTH.

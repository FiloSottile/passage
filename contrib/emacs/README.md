# Emacs password-store

This package provides functions for working with pass ("the standard
Unix password manager").

http://www.zx2c4.com/projects/password-store

## Setup

The pass application must be installed and set up. See the pass
website for instructions

## Example usage

Interactive:

    M-x password-store-insert
    Password entry: foo-account
    Password: ........
    Confirm password: ........

    M-x password-store-copy
    Password entry: foo-account
    Copied password for foo-account to the kill ring. Will clear in 45 seconds.
    Field password cleared.

    M-x password-store-copy-field
    Password entry: foo-account
    Field: username
    Copied username for foo-account to the kill ring. Will clear in 45 seconds.
    Field url cleared.


Lisp:

    (password-store-insert "foo-account" "password")
    (password-store-get "foo-account") ; Returns "password"
    (password-store-get-field "foo-account" "url") ; Returns "url"

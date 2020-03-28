# 2.1.4

* Drop dependency on f library.

# 2.1.3

* Update password-store-clear docstring; clarify that the
  optional argument is only used in the print out message.

# 2.1.2

* Make argument optional in password-store-clear to preserve
  backward compatibility.

# 2.1.1

* (bugfix) Check that auth-source-pass-filename is bound before use it.

# 2.1.0

* (feature) Support extraction of any secret fields stored in the files.

* (feature) The library is now integrated with auth-source-pass; thus, the
            filename of the password-store folder is set with the option
            auth-source-pass-filename.

# 2.0.5

Improve password-store-insert message on success/failure

# 2.0.4
	
* Re add password-store-timeout function to preserve backward
  compatibility with other libraries relying on it.
	
# 2.0.3
	
* (feature) Update password-store-password-length default value to 25
	
* (feature) Add option password-store-time-before-clipboard-restore; delete
            password-store-timeout and use the new option instead.
	
# 1.0.2

* (bugfix) Fix typo in password-store-url function doc string

# 1.0.1

* (bugfix) Quote shell arguments in async call

# 1.0.0

* (feature) Call `pass edit` so that changes get committed to git

# 0.1

* Initial release

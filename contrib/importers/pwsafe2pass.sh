#!/usr/bin/env bash
# Copyright (C) 2013 Tom Hendrikx <tom@whyscream.net>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

export=$1

IFS="	" # tab character
cat "$export" | while read uuid group name login passwd notes; do
     test "$uuid" = "# passwordsafe version 2.0 database" && continue
     test "$uuid" = "uuid" && continue
     test "$name" = '""' && continue;

     group="$(echo $group | cut -d'"' -f2)"
     login="$(echo $login | cut -d'"' -f2)"
     passwd="$(echo $passwd | cut -d'"' -f2)"
     name="$(echo $name | cut -d'"' -f2)"

     # cleanup
     test "${name:0:4}" = "http" && name="$(echo $name | cut -d'/' -f3)"
     test "${name:0:4}" = "www." && name="$(echo $name | cut -c 5-)"

     entry=""
     test -n "$login" && entry="${entry}login: $login\n"
     test -n "$passwd" && entry="${entry}pass: $passwd\n"
     test -n "$group" && entry="${entry}group: $group\n"

     echo Adding entry for $name:
     echo -e $entry | pass insert --multiline --force "$name"
     test $? && echo "Added!"
done

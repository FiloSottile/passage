#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2012 Antoine Beaupré <anarcat@orangeseeds.org>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.
#
# To double-check your import worked:
# grep Path passwords | sed 's#^Path: ##;s/$/.gpg/' | sort > listpaths
# (cd ~/.password-store/ ; find -type f ) | sort | diff -u - listpaths

import re
import fileinput

import sys # for exit

import subprocess

def insert(d):
    path = d['Path']
    del d['Path']
    print "inserting " + path
    content = d['Password'] + "\n"
    del d['Password']
    for k, v in d.iteritems():
        content += "%s: %s\n" % (k, v)
    del d
    cmd = ["pass", "insert", "--force", "--multiline", path]
    process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate(content)
    retcode = process.wait()
    if retcode:
        print 'command "%s" failed with exit code %d: %s' % (" ".join(cmd), retcode, stdout + stderr)
        sys.exit(1);

d = None
for line in fileinput.input():
    if line == "\n":
        continue
    match = re.match("(\w+): (.*)$", line)
    if match:
        if match.group(1) == 'Path':
            if d is not None:
                insert(d)
            else:
                d = {}
        d[match.group(1)] = match.group(2)
        #print "found field: %s => %s" % (match.group(1), match.group(2))
    else:
        print "warning: no match found on line: *%s*" % line

if d is not None:
    insert(d)

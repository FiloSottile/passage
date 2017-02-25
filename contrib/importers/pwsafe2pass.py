#!/usr/bin/env python3

# Copyright (C) 2017 Sam Mason <sam@samason.uk>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

import sys
import subprocess

import pandas as pd

# assumes STDIN is generated via File=>Export from the Mac version of
# pwsafe, available from https://pwsafe.info/
df = pd.read_table(sys.stdin)
df.sort_values(['Group/Title','Username'], inplace=True)

tr = {
    ord('.'): '/',
    ord('»'): '.'
}

for i,row in df.iterrows():
    na = row.notnull()

    path = 'pwsafe/{}'.format(row['Group/Title'].strip().translate(tr))
    value = '{}\n'.format(row['Password'])

    if na['Username']:
        path = '{}/{}'.format(path,row['Username'].strip())

    if na['e-mail']:
        value = 'email: {}\n'.format(value,row['e-mail'].strip())

    if na['Notes']:
        value = '\n{}\n'.format(value, row['Notes'].strip())

    with subprocess.Popen(['pass','add','-m',path],stdin=subprocess.PIPE) as proc:
        proc.communicate(value.encode('utf8'))
        if proc.returncode:
            print('failure with {}, returned {}'.format(
                path, proc.returncode))

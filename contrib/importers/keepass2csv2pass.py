#!/usr/bin/env python3

# Copyright 2015 David Francoeur <dfrancoeur04@gmail.com>
# Copyright 2017 Nathan Sommer <nsommer@wooster.edu>
#
# This file is licensed under the GPLv2+. Please see COPYING for more
# information.
#
# KeePassX 2+ on Mac allows export to CSV. The CSV contains the following
# headers:
# "Group","Title","Username","Password","URL","Notes"
#
# By default the pass entry will have the path Group/Title/Username and will
# have the following structure:
#
# <Password>
# user: <Username>
# url: <URL>
# notes: <Notes>
#
# Any missing fields will be omitted from the entry. If Username is not present
# the path will be Group/Title.
#
# The username can be left out of the path by using the --name_is_original
# switch. Group and Title can be converted to lowercase using the --to_lower
# switch. Groups can be excluded using the --exclude_groups option.
#
# Default usage: ./keepass2csv2pass.py input.csv
#
# To see the full usage: ./keepass2csv2pass.py -h

import sys
import csv
import argparse
from subprocess import Popen, PIPE


class KeepassCSVArgParser(argparse.ArgumentParser):
    """
    Custom ArgumentParser class which prints the full usage message if the
    input file is not provided.
    """
    def error(self, message):
        print(message, file=sys.stderr)
        self.print_help()
        sys.exit(2)


def pass_import_entry(path, data):
    """Import new password entry to password-store using pass insert command"""
    proc = Popen(['pass', 'insert', '--multiline', path], stdin=PIPE,
                 stdout=PIPE)
    proc.communicate(data.encode('utf8'))
    proc.wait()


def confirmation(prompt):
    """
    Ask the user for 'y' or 'n' confirmation and return a boolean indicating
    the user's choice. Returns True if the user simply presses enter.
    """

    prompt = '{0} {1} '.format(prompt, '(Y/n)')

    while True:
        user_input = input(prompt)

        if len(user_input) > 0:
            first_char = user_input.lower()[0]
        else:
            first_char = 'y'

        if first_char == 'y':
            return True
        elif first_char == 'n':
            return False

        print('Please enter y or n')


def insert_file_contents(filename, preparation_args):
    """ Read the file and insert each entry """

    entries = []

    with open(filename, 'rU') as csv_in:
        next(csv_in)
        csv_out = (line for line in csv.reader(csv_in, dialect='excel'))
        for row in csv_out:
            path, data = prepare_for_insertion(row, **preparation_args)
            if path and data:
                entries.append((path, data))

    if len(entries) == 0:
        return

    print('Entries to import:')

    for (path, data) in entries:
        print(path)

    if confirmation('Proceed?'):
        for (path, data) in entries:
            pass_import_entry(path, data)
            print(path, 'imported!')


def prepare_for_insertion(row, name_is_username=True, convert_to_lower=False,
                          exclude_groups=None):
    """Prepare a CSV row as an insertable string"""

    group = escape(row[0])
    name = escape(row[1])

    # Bail if we are to exclude this group
    if exclude_groups is not None:
        for exclude_group in exclude_groups:
            if exclude_group.lower() in group.lower():
                return None, None

    # The first component of the group is 'Root', which we do not need
    group_components = group.split('/')[1:]

    path = '/'.join(group_components + [name])

    if convert_to_lower:
        path = path.lower()

    username = row[2]
    password = row[3]
    url = row[4]
    notes = row[5]

    if username and name_is_username:
        path += '/' + username

    data = '{}\n'.format(password)

    if username:
        data += 'user: {}\n'.format(username)

    if url:
        data += 'url: {}\n'.format(url)

    if notes:
        data += 'notes: {}\n'.format(notes)

    return path, data


def escape(str_to_escape):
    """ escape the list """
    return str_to_escape.replace(" ", "-")\
                        .replace("&", "and")\
                        .replace("[", "")\
                        .replace("]", "")


def main():
    description = 'Import pass entries from an exported KeePassX CSV file.'
    parser = KeepassCSVArgParser(description=description)

    parser.add_argument('--exclude_groups', nargs='+',
                        help='Groups to exclude when importing')
    parser.add_argument('--to_lower', action='store_true',
                        help='Convert group and name to lowercase')
    parser.add_argument('--name_is_original', action='store_true',
                        help='Use the original entry name instead of the '
                             'username for the pass entry')
    parser.add_argument('input_file', help='The CSV file to read from')

    args = parser.parse_args()

    preparation_args = {
        'convert_to_lower': args.to_lower,
        'name_is_username': not args.name_is_original,
        'exclude_groups': args.exclude_groups
    }

    input_file = args.input_file
    print("File to read:", input_file)
    insert_file_contents(input_file, preparation_args)


if __name__ == '__main__':
    main()

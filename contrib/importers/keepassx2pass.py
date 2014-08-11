#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2012 Juhamatti Niemelä <iiska@iki.fi>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

import sys
import re

from subprocess import Popen, PIPE
from xml.etree import ElementTree

def space_to_camelcase(value):
    output = ""
    first_word_passed = False
    for word in value.split(" "):
        if not word:
            output += "_"
            continue
        if first_word_passed:
            output += word.capitalize()
        else:
            output += word.lower()
        first_word_passed = True
    return output

def cleanTitle(title):
    # make the title more command line friendly
    title = re.sub("(\\|\||\(|\)|/)", "-", title)
    title = re.sub("-$", "", title)
    title = re.sub("\@", "At", title)
    title = re.sub("'", "", title)
    return title

def path_for(element, path=''):
    """ Generate path name from elements title and current path """
    title_text = element.find('title').text
    if title_text is None:
        title_text = ''
    title = cleanTitle(space_to_camelcase(title_text))
    return '/'.join([path, title])

def password_data(element):
    """ Return password data and additional info if available from
    password entry element. """
    passwd = element.find('password').text
    ret = passwd + "\n" if passwd else "\n"
    for field in ['username', 'url', 'comment']:
        fel = element.find(field)
        children = [unicode(e.text or '') + unicode(e.tail or '') for e in list(fel)]
        if len(children) > 0:
            children.insert(0, '')
        text = (fel.text or '') + "\n".join(children)
        if len(text) > 0:
            ret = "%s%s: %s\n" % (ret, fel.tag, text)
    return ret

def import_entry(element, path=''):
    """ Import new password entry to password-store using pass insert
    command """
    print "Importing " + path_for(element, path)
    proc = Popen(['pass', 'insert', '--multiline', '--force',
                  path_for(element, path)],
              stdin=PIPE, stdout=PIPE)
    proc.communicate(password_data(element).encode('utf8'))
    proc.wait()

def import_group(element, path=''):
    """ Import all entries and sub-groups from given group """
    npath = path_for(element, path)
    for group in element.findall('group'):
        import_group(group, npath)
    for entry in element.findall('entry'):
        import_entry(entry, npath)


def main(xml_file):
    """ Parse given KeepassX XML file and import password groups from it """
    for group in ElementTree.parse(xml_file).findall('group'):
        import_group(group)

if __name__ == '__main__':
    main(sys.argv[1])

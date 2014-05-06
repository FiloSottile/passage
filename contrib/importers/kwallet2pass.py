#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2012 Juhamatti Niemelä <iiska@iki.fi>. All Rights Reserved.
# Copyright (C) 2014 Diggory Hardy <diggory.hardy@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

import sys
import re

from subprocess import Popen, PIPE
from xml.etree import ElementTree

HEAD = '/passwords/'

def insert_data(path,text):
    """ Insert data into the password store.
    (1) removes HEAD from path
    (2) ensures text ends with a new line and encodes in UTF-8
    (3) inserts
    """
    global HEAD
    if path.startswith(HEAD):
        path = path[len(HEAD):]
    
    if not text.endswith('\n'):
        text = text + '\n'
    text = text.encode('utf8')
    
    #print "Import: " + path + ": " + text
    proc = Popen(['pass', 'insert', '--multiline', '--force', path],
                 stdin=PIPE, stdout=PIPE)
    proc.communicate(text)
    proc.wait()

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
    title = cleanTitle(space_to_camelcase(element.attrib['name']))
    return '/'.join([path, title])

def unexpected(element, path):
    print "Unexpected element: " + path + '/' + element.tag + "\tAttributes: " + str(element.attrib)

def import_map(element, path):
    npath = path_for(element, path)
    nEntries = 0
    text = 'Map'
    for child in element:
        if child.tag == 'mapentry':
            name = child.attrib['name']
            text = text + '\n\n' + name + '\n' + child.text
            nEntries += 1
            for child2 in child:
                unexpected(child, path_for(child, npath))
        else:
            unexpected(child, npath)
    
    insert_data(npath, text)
    print "Map " + npath + " [" + str(nEntries) + " entries]"

def import_password(element, path=''):
    """ Import new password entry to password-store using pass insert
    command """
    npath = path_for(element, path)
    text = element.text
    if text == None:
        print "Password " + npath + ": no text"
        text = ""
    insert_data(npath, text)
    for child in element:
        unexpected(child, npath)

def import_folder(element, path=''):
    """ Import all entries and folders from given folder """
    npath = path_for(element, path)
    print "Importing folder " + npath
    nPasswords = 0
    for child in element:
        if child.tag == 'folder':
            import_folder(child, npath)
        elif child.tag == 'password':
            import_password(child, npath)
            nPasswords += 1
        elif child.tag == 'map':
            import_map(child, npath)
        else:
            unexpected(child, npath)
    
    if nPasswords > 0:
        print "[" + str(nPasswords) + " passwords]"

def main(xml_file):
    """ Parse XML entries from a KWallet """
    element = ElementTree.parse(xml_file).getroot()
    assert element.tag == 'wallet'
    import_folder(element)

if __name__ == '__main__':
    main(sys.argv[1])

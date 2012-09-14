#! /usr/bin/env python

import sys

from subprocess import Popen, PIPE
from xml.etree import ElementTree

def path_for(element, path=''):
    """ Generate path name from elements title and current path """
    title = element.find('title').text
    return '/'.join([path, title])

def import_entry(element, path=''):
    """ Import new password entry to password-store using pass insert
    command """
    proc = Popen(['pass', 'insert', path_for(element, path)],
              stdin=PIPE, stdout=PIPE)
    proc.communicate(element.find('password').text + "\n")
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
    with open(xml_file) as xml:
        for group in ElementTree.XML(xml.read()).findall('group'):
            import_group(group)

if __name__ == '__main__':
    main(sys.argv[1])

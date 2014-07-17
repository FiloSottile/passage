#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2013 Emanuele Aina <em@nerd.ocracy.org>. All Rights Reserved.
# Copyright (C) 2011 Toni Corvera. All Rights Reserved.
# This file is licensed under the BSD 2-clause license:
# http://www.opensource.org/licenses/BSD-2-Clause
#
# Import script for the Revelation password manager:
# http://revelation.olasagasti.info/
# Heavily based on the Relevation command line tool:
# http://p.outlyer.net/relevation/

import os, sys, argparse, zlib, getpass, traceback
from subprocess import Popen, PIPE, STDOUT, CalledProcessError
from collections import OrderedDict
try:
    from lxml import etree
except ImportError:
    from xml.etree import ElementTree as etree

USE_PYCRYPTO = True
try:
    from Crypto.Cipher import AES
except ImportError:
    USE_PYCRYPTO = False
    try:
        from crypto.cipher import rijndael, cbc
        from crypto.cipher.base import noPadding
    except ImportError:
        sys.stderr.write('Either PyCrypto or cryptopy are required\n')
        raise

def path_for(element, path=None):
    """ Generate path name from elements name and current path """
    name = element.find('name').text
    name = name.replace('/', '-').replace('\\', '-')
    path = path if path else ''
    return os.path.join(path, name)

def format_password_data(data):
    """ Format the secret data that will be handed to Pass in multi-line mode:
    $password
    $fieldname: $fielddata
    ...
     $multi_line_notes_with_leading_spaces"""
    password = data.pop('password', None) or ''
    ret = password + '\n'
    notes = data.pop('notes', None)
    for label, text in data.iteritems():
        ret += label + ': ' + text + '\n'
    if notes:
        ret += ' ' + notes.replace('\n', '\n ').strip() + '\n'
    return ret

def password_data(element):
    """ Return password data and additional info if available from
    password entry element. """
    data = OrderedDict()
    try:
        data['password'] = element.find('field[@id="generic-password"]').text
    except AttributeError:
        data['password'] = None
    data['type'] = element.attrib['type']
    for field in element.findall('field'):
        field_id = field.attrib['id']
        if field_id == 'generic-password':
            continue
        if field.text is not None:
            data[field_id] = field.text
    for tag in ('description', 'notes'):
        field = element.find(tag)
        if field is not None and field.text:
            data[tag] = field.text
    return format_password_data(data)


def import_entry(element, path=None, verbose=0):
    """ Import new password entry to password-store using pass insert
    command """
    cmd = ['pass', 'insert', '--multiline', '--force', path_for(element, path)]
    if verbose:
        print 'cmd:\n ' + ' '.join(cmd)
    proc = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=STDOUT)
    stdin = password_data(element).encode('utf8')
    if verbose:
        print 'input:\n ' + stdin.replace('\n', '\n ').strip()
    stdout, _ = proc.communicate(stdin)
    retcode = proc.poll()
    if retcode:
        raise CalledProcessError(retcode, cmd, output=stdout)

def import_folder(element, path=None, verbose=0):
    path = path_for(element, path)
    import_subentries(element, path, verbose)

def import_subentries(element, path=None, verbose=0):
    """ Import all sub entries of the current folder element """
    for entry in element.findall('entry'):
        if entry.attrib['type'] == 'folder':
            import_folder(entry, path, verbose)
        else:
            import_entry(entry, path, verbose)

def decrypt_gz(key, cipher_text):
    ''' Decrypt cipher_text using key.
    decrypt(str, str) -> cleartext (gzipped xml)

    This function will use the underlying, available, cipher module.
    '''
    if USE_PYCRYPTO:
        # Extract IV
        c = AES.new(key)
        iv = c.decrypt(cipher_text[12:28])
        # Decrypt data, CBC mode
        c = AES.new(key, AES.MODE_CBC, iv)
        ct = c.decrypt(cipher_text[28:])
    else:
        # Extract IV
        c = rijndael.Rijndael(key, keySize=len(key), padding=noPadding())
        iv = c.decrypt(cipher_text[12:28])
        # Decrypt data, CBC mode
        bc = rijndael.Rijndael(key, keySize=len(key), padding=noPadding())
        c = cbc.CBC(bc, padding=noPadding())
        ct = c.decrypt(cipher_text[28:], iv=iv)
    return ct

def main(datafile, verbose=False, xml=False):
    f = None
    with open(datafile, "rb") as f:
        # Encrypted data
        data = f.read()
    if xml:
        xmldata = data
    else:
        password = getpass.getpass()
        # Pad password
        password += (chr(0) * (32 - len(password)))
        # Decrypt. Decrypted data is compressed
        cleardata_gz = decrypt_gz(password, data)
        # Length of data padding
        padlen = ord(cleardata_gz[-1])
        # Decompress actual data (15 is wbits [ref3] DON'T CHANGE, 2**15 is the (initial) buf size)
        xmldata = zlib.decompress(cleardata_gz[:-padlen], 15, 2**15)
    root = etree.fromstring(xmldata)
    import_subentries(root, verbose=verbose)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-x', '--xml', help='read plain XML file', action='store_true')
    parser.add_argument('--verbose', '-v', action='count')
    parser.add_argument('FILE', help="the file storing the Revelation passwords")
    args = parser.parse_args()

    def err(s):
        sys.stderr.write(s+'\n')

    try:
        main(args.FILE, verbose=args.verbose, xml=args.xml)
    except KeyboardInterrupt:
        if args.verbose:
            traceback.print_exc()
            err(str(e))
    except zlib.error:
        err('Failed to decompress decrypted data. Wrong password?')
        sys.exit(os.EX_DATAERR)
    except CalledProcessError as e:
        if args.verbose:
            traceback.print_exc()
            print 'output:\n ' + e.output.replace('\n', '\n ').strip()
        else:
            err('CalledProcessError: ' + str(e))
        sys.exit(os.EX_IOERR)
    except IOError as e:
        if args.verbose:
            traceback.print_exc()
        else:
            err('IOError: ' + str(e))
        sys.exit(os.EX_IOERR)

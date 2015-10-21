#!/usr/bin/env python3

# Copyright 2015 David Francoeur <dfrancoeur04@gmail.com>
# This file is licensed under the GPLv2+. Please see COPYING for more information.

# KeePassX 2+ on Mac allows export to CSV. The CSV contains the following headers :
# "Group","Title","Username","Password","URL","Notes"
# Group and Title are used to build the path, @see prepareForInsertion
# Password is the first line and the url and the notes are appended after
#
# Usage: ./csv_to_pass.py test.csv

import csv
import itertools
import sys
from subprocess import Popen, PIPE

def pass_import_entry(path, data):
	""" Import new password entry to password-store using pass insert command """
	proc = Popen(['pass', 'insert', '--multiline', path], stdin=PIPE, stdout=PIPE)
	proc.communicate(data.encode('utf8'))
	proc.wait()

def readFile(filename):
	""" Read the file and proccess each entry """
	with open(filename, 'rU') as csvIN:
		next(csvIN)
		outCSV=(line for line in csv.reader(csvIN, dialect='excel'))
		#for row in itertools.islice(outCSV, 0, 1):
		for row in outCSV:
			#print("Length: ", len(row), row) 
			prepareForInsertion(row)


def prepareForInsertion(row):
	""" prepare each CSV entry into an insertable string """
	keyFolder = escape(row[0][4:])
	keyName = escape(row[1])
	username = row[2]
	password = row[3]
	url = row[4]
	notes = row[5]
	
	path = keyFolder+"/"+keyName+"/"+username
	data = password + "\n" if password else "\n"
	data = "%s%s: %s\n" % (data, "url:", url+"\n")
	data = "%s%s: %s\n" % (data, "notes:", notes+"\n")
	pass_import_entry(path,data) 
	print(path+" imported!")

def escape(strToEscape):
	""" escape the list """
	return strToEscape.replace(" ", "-").replace("&","and").replace("[","").replace("]","")
	

def main(argv):
	inputFile = sys.argv[1]
	print("File to read: " + inputFile)
	readFile(inputFile)


main(sys.argv)

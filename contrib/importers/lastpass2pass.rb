#!/usr/bin/env ruby

# Copyright (C) 2012 Alex Sayers <alex.sayers@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

# LastPass Importer
#
# Reads CSV files exported from LastPass and imports them into pass.

# Usage:
#
# Go to lastpass.com and sign in. Next click on your username in the top-right
# corner. In the drop-down meny that appears, click "Export". After filling in
# your details again, copy the text and save it somewhere on your disk. Make sure
# you copy the whole thing, and resist the temptation to "Save Page As" - the
# script doesn't like HTML.
#
# Fire up a terminal and run the script, passing the file you saved as an argument.
# It should look something like this:
#
#$ ./lastpass2pass.rb path/to/passwords_file.csv

# Parse flags
require 'optparse'
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] filename"

  FORCE = false
  opts.on("-f", "--force", "Overwrite existing records") { FORCE = true }
  DEFAULT_GROUP = ""
  opts.on("-d", "--default GROUP", "Place uncategorised records into GROUP") { |group| DEFAULT_GROUP = group }
  opts.on("-h", "--help", "Display this screen") { puts opts; exit }

  opts.parse!
end

# Check for a filename
if ARGV.empty?
  puts optparse
  exit 0
end

# Get filename of csv file
filename = ARGV.join(" ")
puts "Reading '#{filename}'..."


class Record
  def initialize name, url, username, password, extra, grouping, fav
    @name, @url, @username, @password, @extra, @grouping, @fav = name, url, username, password, extra, grouping, fav
  end

  def name
    s = ""
    s << @grouping + "/" unless @grouping.empty?
    s << @name unless @name == nil
    s.gsub(/ /, "_").gsub(/'/, "")
  end

  def to_s
    s = ""
    s << "#{@password}\n---\n"
    s << "#{@grouping} / " unless @grouping.empty?
    s << "#{@name}\n"
    s << "username: #{@username}\n" unless @username.empty?
    s << "password: #{@password}\n" unless @password.empty?
    s << "url: #{@url}\n" unless @url == "http://sn"
    s << "#{@extra}\n" unless @extra.nil?
    return s
  end
end

# Extract individual records
entries = []
entry = ""
begin
  file = File.open(filename)
  file.each do |line|
    if line =~ /^(http|ftp|ssh)/
      entries.push(entry)
      entry = ""
    end
    entry += line
  end
  entries.push(entry)
  entries.shift
  puts "#{entries.length} records found!"
rescue
  puts "Couldn't find #{filename}!"
  exit 1
end

# Parse records and create Record objects
records = []
entries.each do |e|
  args = e.split(",")
  url = args.shift
  username = args.shift
  password = args.shift
  fav = args.pop
  grouping = args.pop
  grouping = DEFAULT_GROUP if grouping == nil
  name = args.pop
  extra = args.join(",")[1...-1]

  records << Record.new(name, url, username, password, extra, grouping, fav)
end
puts "Records parsed: #{records.length}"

successful = 0
errors = []
records.each do |r|
  if File.exist?("#{r.name}.gpg") and FORCE == false
    puts "skipped #{r.name}: already exists"
    next
  end
  print "Creating record #{r.name}..."
  IO.popen("pass insert -m '#{r.name}' > /dev/null", 'w') do |io|
    io.puts r
  end
  if $? == 0
    puts " done!"
    successful += 1
  else
    puts " error!"
    errors << r
  end
end
puts "#{successful} records successfully imported!"

if errors.length > 0
  puts "There were #{errors.length} errors:"
  errors.each { |e| print e.name + (e == errors.last ? ".\n" : ", ")}
  puts "These probably occurred because an identically-named record already existed, or because there were multiple entries with the same name in the csv file."
end

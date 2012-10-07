#!/usr/bin/env ruby

# Copyright (C) Alex Sayers <alex.sayers@gmail.com>. All Rights Reserved. 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
# ./lastpass_importer.rb path/to/passwords_file


# Set this variable to place all uncategorised records into a particular group
DEFAULT_GROUP = ""

class Record
  def initialize name, url, username, password, extra, grouping, fav
    @name, @url, @username, @password, @extra, @grouping, @fav = name, url, username, password, extra, grouping, fav
  end

  def name
    s = ""
    s << @grouping + "/" unless @grouping.empty?
    s << @name
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

# Check for a filename
if ARGV.empty?
  puts "Usage: lastpass_importer.rb <file>      import records from specified file"
  exit 0
end

# Get filename of csv file
filename = ARGV.join(" ")
puts "Reading '#{filename}'..."

# Extract individual records
entries = []
entry = ""
begin
  file = File.open(filename)
  file.each do |line|
    if line =~ /^http/
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
  grouping = DEFAULT_GROUP if grouping.empty?
  name = args.pop
  extra = args.join(",")[1...-1]
  
  records << Record.new(name, url, username, password, extra, grouping, fav)
end
puts "Records parsed: #{records.length}"

successful = 0
errors = []
records.each do |r|
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

if errors
  puts "There were #{errors.length} errors:"
  errors.each { |e| print e.name + (e == errors.last ? ".\n" : ", ")}
  puts "These probably occurred because an identically-named record already existed, or because there were multiple entries with the same name in the csv file."
end

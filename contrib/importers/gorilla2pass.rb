#!/usr/bin/env ruby

# Copyright (C) 2013 David Sklar <david.sklar@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

entries = {}

class HashCounter

  def initialize
    @h = Hash.new {|h,k| h[k] = 2 }
  end

  def get(k)
    v = @h[k]
    @h[k] = v + 1
    v
  end
end

hc = HashCounter.new

$stdin.each do |line|
  uuid, group, title, url, user, password, notes = line.strip.split(',')
  next if uuid == "uuid"

  # check for missing group
  # check for missing title

  prefix = "#{group}/#{title}".gsub(/[\s\'\"()!]/,'')


  if user && user.length > 0
    entries["#{prefix}/user"] = user
  end
  if url && url.length > 0
    entries["#{prefix}/url"] = url
  end
  if password && password.length > 0
    entries["#{prefix}/password"] = password
  end
  if notes && notes.length > 0
    entries["#{prefix}/notes"] = notes.gsub('\n',"\n").strip
  end
end

entries.keys.each do |k|
  if k =~ /^(.+?)-merged\d{4}-\d\d-\d\d\d\d:\d\d:\d\d(\/.+)$/
    other = $1 + $2
    if entries.has_key?(other)
      if entries[k] == entries[other]
        entries.delete(k)
      else
        i = hc.get(other)
        entries["#{other}#{i}"] = entries[k]
        entries.delete(k)
      end
    else
      entries[other] = entries[k]
      entries.delete(k)
    end
  end
end

pass_top_level = "Gorilla"
entries.keys.each do |k|
  print "#{k}...(#{entries[k]})..."
  IO.popen("pass insert -e -f '#{pass_top_level}/#{k}' > /dev/null", 'w') do |io|
    io.puts entries[k] + "\n"
  end
  if $? == 0
    puts " done!"
  else
    puts " error!"
  end
end

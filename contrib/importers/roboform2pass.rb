#!/usr/bin/env ruby

# Copyright 2015 Sergey Makridenkov <sergey@makridenkov.com>.
# Released under MIT License.
#
# Usage:
#    1. Save roboform print lists (like File > Print lists > Logins) to ~/roboform_print_lists.
#    2. Run import: ./roboform2pass.rb ~/roboform_print_lists


require 'nokogiri'

class Login
  def initialize
    self.fields = {}
    self.raw = []
  end

  attr_accessor :key
  attr_accessor :password
  attr_accessor :url
  attr_accessor :fields
  attr_accessor :raw

  def ask_required_info
    ask!(:key) if blank?(key)
    find_password!
    if blank?(password)
      ask!(:password)
      puts ''
    end
  end

  def save
    if valid?
      IO.popen("pass insert -m -f '#{path}' > /dev/null", "w") do |pass_io|
        pass_io.puts password
        pass_io.puts "Url: #{url}" if present?(url)
        pass_io.puts "Fields: #{fields}" if fields.any?
        pass_io.puts "Notes: #{raw}" if raw.any?
      end

      $? == 0
    end
  end

  private

  def path
    key = self.key.downcase.gsub(/[^\w\.\/]/, '_').gsub(/_{2,}/, '_')
    "roboform/#{key}"
  end

  def valid?
    present?(key) && present?(password)
  end

  def find_password!
    fields.each do |key, val|
      key = key.downcase
      if key.include?('password') || key.include?('pwd') || key.include?('pass')
        self.password = val
      end
    end
  end

  def ask!(field)
    puts Colorize.red("#{field.capitalize} is empty for login:")
    print_self
    print Colorize.green "Please type #{field}: "
    self.send("#{field}=", gets.chomp)
  end

  def print_self
    puts Colorize.yellow "\tKey:\t#{key}" if present?(key)
    puts Colorize.yellow "\tPassword:\t#{password}" if present?(password)
    puts Colorize.yellow "\tUrl:\t#{url}" if present?(url)
    puts Colorize.yellow "\tFields:\t#{fields}" if fields.any?
    puts Colorize.yellow "\tRaw:\t#{raw}" if raw.any?
  end

  def blank?(str)
    !str || str.strip.empty?
  end

  def present?(str)
    !blank?(str)
  end
end

class Colorize
  class << self
    def red(mes)
      colorize(31, mes)
    end

    def green(mes)
      colorize(32, mes)
    end

    def yellow(mes)
      colorize(33, mes)
    end

    def pink(mes)
      colorize(35, mes)
    end

    private

    def colorize(color_code, mes)
      "\e[#{color_code}m#{mes}\e[0m"
    end
  end
end


print_list_dir = ARGV.pop
unless print_list_dir
  raise "No dir/to/roboform/print_lists"
end
print_list_dir = File.expand_path(print_list_dir)

# parse logins
logins_path = Dir.glob("#{print_list_dir}/RoboForm Logins*.html").first
unless logins_path
  raise 'Login HTML (RoboForm Logins*.html) not found'
end

html_logins = Nokogiri::HTML(File.open(logins_path))

saved_logins = 0

html_logins.css('table').each do |table|
  login = Login.new

  table.css('tr').each do |tr|
    caption = tr.at_css('.caption')
    subcaption = tr.at_css('.subcaption')
    key = tr.at_css('.field')

    if caption
      login.key = caption.text()
    elsif subcaption
      login.url = subcaption.text()
    elsif key
      login.fields[key.text()] = tr.at_css('.wordbreakfield').text()
    else
      login.raw << tr.at_css('.wordbreakfield').text()
    end
  end

  if login.fields.any?
    login.ask_required_info
    if login.save
      saved_logins += 1
    end
  end
end

puts "Imported passwords: #{saved_logins}"


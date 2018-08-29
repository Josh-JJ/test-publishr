# coding: UTF-8

# PublishR -- Rapid publishing for ebooks (epub, Kindle), paper (LaTeX) and the web (webgen)'
# Copyright (C) 2012 Red (E) Tools Ltd. (www.red-e.eu)
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Publishr
  class RewriteProcessor
    attr_accessor :target, :metadata
    def initialize(target,metadata)
      @target = target
      @metadata = metadata
      @rules = {}
      @contents = ''
    end
    #
    def run(action,text)
      parse_file(action)
      parse_file("always")
      keys = @rules.keys.sort
      puts @rules.inspect
      keys.each do |key|
        puts "Accessing key: #{key}"
        rules_to_apply = @rules[key]
        rules_to_apply.each do |rule|
        puts rule.inspect
          if rule[0] and rule[1] then
            
            lside,rside = rule
            
            # so that we can have things like 1000  \x0096   -- 
            # and 1001  \x0092  '
            if lside.match(/\\x[ABCDEF\d]+/) then
              lside.gsub!(/(\\x[ABCDEF\d]+)/) { $1.gsub('\x','').hex.chr }
              puts "Replacing hex: #{lside}"
            end
            
            rside = '' if rside == 'nil'
            
            text.gsub!(lside,rside)
          else
            puts "Rule empty"
          end # if rule[0] and rule[1] then
        end # rules_to_apply.each do |rule|
      end #  keys.each do |key|
      return text
    end
    #
    def parse_file(action)
      fname = File.join(@target,"#{action}.rewrite")
      if File.exists?(fname) then
        @contents = File.open(fname,'r') { |f| f.read }
        @contents.split("\n").each do |line|
          parts = line.split("||")
          @rules[parts[0]] ||= []
          @rules[parts[0]] << [parts[1],parts[2]]
        end
      end
    end
  end
end

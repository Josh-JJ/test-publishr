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
  class Helper
    def self.strip_webgen_header_from_page_file(content)
      lines = content.split("\n").reverse
      stripped_content = []
      lines.each do |line|
        break if line.strip == '---'
        stripped_content << line
      end
      return stripped_content.reverse.join("\n")
    end
    
    def self.get_footnote_count_upto_file(inpath, language, filename)
      language = language.include?('.') ? language : ".#{language}" # inside of the whole publishr gem, @language must be prefixed with a dot
      total_footnote_count = 0
      Dir[File.join(inpath,"*#{ language }.page")].sort.each do |f|
        break if File.basename(f) == filename
        footnotes_in_this_file = `grep -P '^\\[\\^.*?\\]\\:' #{ f }`.split("\n").size
        total_footnote_count += footnotes_in_this_file
        Publishr.log "XXX footnotes_in_this_file #{ File.basename(f) } : #{ footnotes_in_this_file }"
      end
      Publishr.log "XXX total_footnote_count #{ filename }: #{ total_footnote_count }\n\n"
      return total_footnote_count
    end
  
    def self.copy_images(inpath, outpath, language, filetype)
      # Copy all unlocalized images
      Dir[File.join(inpath,'images',"*.#{ filetype }")].each do |i|
        basename = File.basename(i)
        FileUtils.cp i, outpath if basename.count('.') == 1
      end
        
      # Copy all localized images, but only for the selected language
      Dir[File.join(inpath,'images',"*#{ language }.#{ filetype }")].each do |i|
        basename = File.basename(i)
        FileUtils.cp i, outpath
      end
    end
  end
end
    
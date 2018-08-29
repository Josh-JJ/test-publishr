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
  class KramdownProcessor

    def initialize(inpath, metadata={}, language=nil, image_url_prefix='')
      @inpath = inpath
      @metadata = metadata
      if language and not language.empty?
        @language = language.include?('.') ? language : ".#{language}" # inside of the whole publishr gem, @language must be prefixed with a dot
      else
        @language = nil
      end
      @image_url_prefix = image_url_prefix
      @kramdown_preprocessing = File.open(File.join(@inpath,"kramdown_preprocessing#{ @language }.rb"), 'r').read if File.exists?(File.join(@inpath,"kramdown_preprocessing#{ @language }.rb"))
    end

    def convert_from_html(html)
      kramdown = Kramdown::Document.new(html, :input => 'html', :line_width => 100000 ).to_kramdown
      kramdown.gsub!(/\!\[(.*?)\]\((.*?)\)/){ "![#{$1}](#{@image_url_prefix}#{$2})" }
      kramdown.gsub! '\"', '"'
      kramdown.gsub! "\\'", "'"
      kramdown.gsub! "\\[", "["
      kramdown.gsub! "\\]", "]"
      return kramdown
    end

    def preprocess(kramdown)
      processed_lines = Array.new
      lines = kramdown.split("\n")
      lines.each do |line|
        eval(@kramdown_preprocessing, binding) if @kramdown_preprocessing
        line.gsub!(/^\s*$/, '') # strip lines with only spaces, kramdown fix
        line.gsub!('{::comment}\pagebreak{:/}', "<br style='page-break-before:always;'>") # same page break syntax for ebook and latex
        processed_lines << line
      end
      return processed_lines.join("\n")
    end

  end
end

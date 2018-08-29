# encoding: UTF-8

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
  class HtmlProcessor
    def initialize(inpath='', metadata={}, language=nil, rails_resources_url='')
      @line = ''
      @inpath = inpath
      @metadata = metadata
      if language and not language.empty?
        @language = language.include?('.') ? language : ".#{language}" # inside of the whole publishr gem, @language must be prefixed with a dot
      else
        @language = nil
      end
      @rails_resources_url = rails_resources_url

      @custom_fixes = File.open(File.join(@inpath,"html_postprocessing#{ @language }.rb"), 'r').read if File.exists?(File.join(@inpath,"html_postprocessing#{ @language }.rb"))
      @html_preprocessing = File.open(File.join(@inpath,"html_preprocessing#{ @language }.rb"), 'r').read if File.exists?(File.join(@inpath,"html_preprocessing#{ @language }.rb"))
      
      @images = Dir[File.join(@inpath, 'images', "*.jpg")]
      @images = @images.collect{ |i| File.basename(i) }

      @depth = 0
      @quotetype = nil
      @add_footnote = false
      @process_footnotes = false
      @footnote_number = 0
      @footnote_reference = ''
    end

    def preprocess(html)
      @line = html
      eval(@html_preprocessing, binding) if @html_preprocessing
      return @line
    end

    def sanitize(html)
      html = add_blockquotes(html) if @metadata[:start_quote_strings] and @metadata[:end_quote_strings]
      sanitized_html = Sanitize.clean(html, :elements => ['b','i','em','strong','code','br','var','p','blockquote','img','sup','sub'], :attributes => { 'img' => ['src', 'alt'] })
      return sanitized_html
    end

    # this function adds blockquote tags because .doc files uses arbitrary styles rather than HTML tags
    def add_blockquotes(html)
      @lines = html.split("\n")
      modified_lines = []
      quote_enabled = false
      @lines.each do |line|
        @line = line
        @line.gsub!('<br>', '</p><p>')
        found_quote_start = false
        @metadata[:start_quote_strings].each do |s|
          found_quote_start = @line.include?(s)
          break if found_quote_start == true
        end
        if not quote_enabled and found_quote_start
          modified_lines << "<blockquote>\n"
          quote_enabled = true
        end
        found_quote_end = false
        @metadata[:end_quote_strings].each do |s|
          found_quote_end = @line.include?(s)
          break if found_quote_end == true
        end
        if quote_enabled and found_quote_end
          modified_lines << "</blockquote>\n"
          quote_enabled = false
        end
        modified_lines << @line
      end
      return modified_lines.join("\n")
    end

    def optimize_for_ebook(html)
      @lines = html.split("\n")
      processed_lines = []
      @lines.each do |l|
        @line = l
        process_line
        processed_lines << @line
      end
      return processed_lines.join("\n")
    end

    def process_line
        
      # state machine variables
      @process_footnotes = true if @line.include?('<div class="footnotes">')
      @process_footnotes = false if @process_footnotes == true and @line.include?('</div>')
      if @line.include?('<ol start=')
        # get the first footnote number
        match = /ol start=\"(.*?)\".*/.match(@line)
        @footnote_number = match[1].to_i - 1 if match
      end
      @add_footnote = true and @footnote_number += 1 if @line.include?('<li id="fn')

      eval(@custom_fixes, binding) if @custom_fixes

      annotate_blockquote
      improve_typography
      make_uppercase
      change_footnote_references
      mark_merge_conflicts
      if @line.include?('<img')
        add_image_captions 
        translate_image
      end
      change_resources_url_for_rails unless @rails_resources_url.to_s.empty?
      process_footnotes if @process_footnotes == true
      add_footnote if @add_footnote == true and @line.include?('<p>')
      make_footnote_paragraph if @process_footnotes == true and @line.include?('<p')
    end
    
    def translate_image
      # the user always enters the untranslated image name
      entered_src = /src="(.*?)"/.match(@line)[1]
      translated_src = entered_src.gsub(/\.jpg/, "#{ @language }.jpg")
      # use the translated image instead, if found on filesystem. this was implemete to be consistent with webgen.
      @line.gsub!(/\.jpg/, "#{ @language }.jpg") if @images.include?(translated_src)
    end

    def improve_typography
      @line.gsub!(/title\((.*?)\)/,'<cite>\1</cite>')
      @line.gsub!(/name\((.*?)\)/,'<var>\1</var>')
    end

    # Kindle doesn't recognize <blockquote>, so add class to p tags depending on the blockquote depth
    def annotate_blockquote
      if @line.include?('<blockquote')
        @depth += 1
        @quotetype = /<blockquote class="(.*?)">/.match(@line) if @depth == 1
      end
      if @line.include?('</blockquote')
        @depth -= 1
        @quotetype = nil if @depth.zero?
      end
      @line.gsub!(/<p/,"<p class=\"blockquote_#{ @quotetype[1] if @quotetype }_#{ @depth }\"") unless @depth.zero?
      @line.gsub!(/<li/,"<li class=\"blockquote_#{ @quotetype[1] if @quotetype }_#{ @depth }\"") unless @depth.zero?
      @line.gsub!(/<ul/,"<li class=\"blockquote_#{ @quotetype[1] if @quotetype }_#{ @depth }\"") unless @depth.zero?
    end

    # Kindle doesn't recognize text-transform: uppercase;
    def make_uppercase
      @line.gsub!(/<var>(.*?)<\/var>/){ "<cite>#{ UnicodeUtils.upcase($1) }</cite>" }
      @line.gsub!(/<h1(.*?)>(.*?)<\/h1>/){ "<h1#{ $1 }>#{ UnicodeUtils.upcase($2) }</h1><hr />" }
    end

    def change_footnote_references
      @line.gsub! /<sup id="fnref:.*?">/, ''
      @line.gsub! '</sup>', ''
      @line.gsub! /rel="footnote">(.*?)<\/a>/, '> [\1]</a>'
      @line.gsub!(/(<div class=.footnotes.>)/){ "<br style='page-break-before:always;'>#{ $1 }<h4>#{ @metadata['footnote_heading'] }</h4>" }
    end

    def process_footnotes
      @line.gsub!(/<p(.*?)>/){ "<p>" }
      @footnote_reference = /<li (id="fn.*")/.match(@line)[1] if @line.include?('<li id="fn')
      @line.gsub! /<li id="fn.*>/, ''
      @line.gsub! /<\/li>/, ''
      @line.gsub! /<ol.*?>/, ''
      @line.gsub! /<\/ol>/, ''
      @line.gsub! /<a href="#fnref.*<\/a>/, ''
    end

    # Kindle doesn't display <ol> list numbers when jumping to a footnote, so replace them with conventional text
    def add_footnote
      @line.gsub! /<p>/, "<hr><p #{ @footnote_reference }><b>[#{ @footnote_number }]</b>: "
      @add_footnote = false
    end

    def make_footnote_paragraph
      @line.gsub! /<p/, "<p class='footnote' "
    end

    def change_resources_url_for_rails
      if @line.include?('.css')
        internal_styleheetnames = ['epub.css', 'preview.css']
        internal_styleheetnames.each do |n|
          if @line.include?(n)
            dir = File.dirname(__FILE__)
            epubcss = File.read(File.expand_path("../epub_skeleton/#{ n }", dir))
            @line = "<style>" + epubcss + "</style>"
          end
        end
      else
        @line.gsub!(/href="(.*?.css)/){ "href=\"#{ @rails_resources_url }#{ $1 }" }
      end
      @line.gsub!(/src="(.*?.jpg)/){ "src=\"#{ @rails_resources_url }#{ $1 }" }
    end

    def mark_merge_conflicts
     @line.gsub! /«««.*$/, '<span style="color:red;">'
     @line.gsub! '=======', '</span></p><p><span style="color:orange;">'
     @line.gsub! /»»».*$/, '</span></p>'
    end

    def add_image_captions
      @line.gsub! /<p(.*?)><img src="(.*?)" alt="(.*?)"(.*)\/><\/p>/, '<p class="image"><img src="\2"\1\4/><br /><code>\3</code></p>'
      @line.gsub! /width="(\d*).*?"/, 'width="\1%"'
    end
  end
end

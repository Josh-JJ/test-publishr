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
  class BookProcessor
    attr_accessor :fp, :contents, :target, :metadata,:frontmatter,:endmatter
    # 2 x 2 array where n is what to look for and n + 1 is the replacement and the next element is n + 2
    @@_clean = [
        '”', '"',
        '“', '"',
        '’', "'",
        '‘', "'",
        '…', '...',
        '–', ' -- ',
        '<I>', '<B>', 
        '</I>', '</B>',
        '<B> </B>', ' ',
        '<B></B>', '',
        '</B><B> </B><B>', ' ',
        '</B><B>', '',
        '</B> <B>', ' ',
        '</EM><EM> </EM><EM>', ' ',
        '</EM><EM>', ' ',
        '<EM>', '<I>','</EM>', 
        '</I>','</STRONG>', '',
        '<STRONG>', '',
        '</B><B>', ' ',
        /(\w)<B>/, '\1 <B>',
        '  </B>', '</B>',
        ' </B>', '</B>',
        '<B>  ', '<B>', 
        /\<\!\-\-\[if supportFields\]\>.+\<\!\[endif\]\-\-\>/,''
    ]
    def initialize(target='.', metadata = {})
      @target = target
      @metadata = metadata
      @_margin = 0.0
      @ch_count = 1
      @frontmatter = ['Foreword','Prologue','Preface','Introduction','Copyright Notice','Note to the Reader','Acknowledgements','Books By']
      @endmatter = ['Afterword','Epilogue','Bibliography','Appendix']
      @hp = Publishr::HtmlProcessor.new(target,metadata)
      @kp = Publishr::KramdownProcessor.new(target,metadata)
    end

    def sanitize_and_convert(html)
      i = 0
      while i < @@_clean.length - 1
        html.gsub!(@@_clean[i],@@_clean[i+1])
        i += 2
      end
      nhtml = @kp.convert_from_html(@hp.sanitize(html))
      return nhtml
    end

    def get_file_name(fname)
       
       if fname.match(/Chapter \d+/i) then
        matches = fname.scan(/Chapter (\d+)/i)
        fname = "ch%2.2d" % matches[0][0]
       elsif fname.match(/(#{@frontmatter.join("|")})/i)
         matches = fname.scan(/(#{@frontmatter.join("|")})/i)
         fname = "#{@ch_count }-#{matches[0][0].downcase.gsub(" ",'')}"
         @ch_count  += 1
       elsif fname.match(/(#{@endmatter.join("|")})/i)
        matches = fname.scan(/(#{@endmatter.join("|")})/i)
         fname = "z#{@ch_count }-#{matches[0][0].downcase.gsub(" ",'')}"
         @ch_count  += 1
       else
         fname = fname.gsub(/[^A-Za-z\d]/,'')
         fname = fname[0..65]
       end
       return fname
    end

    def import(html)
      processed_html = @hp.preprocess(html)
      contents = Nokogiri::HTML(processed_html)
      num = 1000
      #footnotes = File.open(File.join(book.target,"footnotes.txt"),'w')
      saved_footnotes = {}
      contents.xpath("//a").each {|a| 
        next if not a[:href] or not (a[:href].include?("footnote") or a[:style].to_s.include?('footnote'))
        # i.e. footnotes have an anchor with either sdfootnote25anc or sdfootnote3sym etc.
        id = a[:href].to_s.gsub("#",'').gsub('sym','').gsub("anc",'') if a[:href]
        if a[:style].to_s.include? 'mso-footnote-id' and id.include? '_' then
          puts "Found mso-footnote" 
          id.gsub!(/^_/,'')
        end
        query = "//div[@id=\"#{id}\"]"
        ft = contents.xpath(query).first.to_s
        new_text = "[^#{num}]"
        nnode = Nokogiri::XML::Node.new("span",contents)
        nnode.inner_html = new_text
        a.replace(nnode)
        # footnotes.puts(new_text + ": " + self.sanitize_and_convert(ft.gsub(/[\n\r]/," "))) if footnotes
        ft = Sanitize.clean(ft, :elements => ['b','i','em','strong','code','br','img'], :attributes => { 'img' => ['src', 'alt'] })
        ft = to_kramdown(ft)
        ft.gsub!(/^\s*\d+\s*/,'')
        saved_footnotes[num.to_s] = new_text + ": " + ft.gsub(/[\n\r]/," ").gsub(/^[0-9]*?\s(.*)$/, '\1')
        
        num += 1
       }
       
      # footnotes.close
      
      # Now let's take care of images embedded in the text
        begin
        contents.xpath("//img").each { |img|
          img_src = img["src"].gsub(/\.jpeg|\.png|\.gif/,".jpg")
# new text to replace image with
new_text = %Q[
{: .H}
![#{img["title"]}](#{img_src})
]
#end new text to replace image with
          nnode = Nokogiri::XML::Node.new("p",contents)
          nnode.inner_html = new_text
          parent = img.parent if img.respond_to? :parent
          while parent and parent.name != 'p' and parent.respond_to? :parent
            parent = parent.parent 
          end
          if parent
            parent.before(nnode)
            img.replace( Nokogiri::XML::Node.new("span",contents) )
          end 
        }
        rescue
          puts "not all images could be converted."
        end
      # end of image code
      
      # Now we separate the chapters
      contents.xpath("//h1").each { |h1|
        @_margin = 0.0
         fname = h1.to_s.gsub(/<\/?[^>]*>/, "").gsub("\n"," ")
         # this is the chapter matcher, you can change it to suit the current doc
         fname = get_file_name(fname)
         node = h1.next
         File.open(File.join(@target,"#{fname}.txt"),'w+') do |f|
           text = ''
           text += parse_node(h1)
           while node.respond_to? :name and node.name != "h1"
             text += parse_node(node)
             node = node.next
           end
           text.gsub!(/\\\[\^(\d+)\\\]/) {"[^#{$1}]"}
           matches = text.scan(/\[\^(\d+)\]/)
           if matches then
            matches.each do |m|
              if saved_footnotes[m[0]] then
                text += "\n" + saved_footnotes[m[0]] + "\n"
              end
            end
           end
           text.gsub!(/^\s*#/,"#")
           f.write(text)
         end # end File.open(File.join(@target,"#{fname}.txt"),'w+') do |f|
      } # end chapter separation
    end # end self.parse
    def parse_node(node)
      headers = ['','h1','h2','h3','h4','h5','h6']
      if headers.include? node.name then
        # we are dealing with a header.
        puts "parse_node called on header: #{node.name}"
        text = "#" * headers.index(node.name) + Sanitize.clean(node.to_s).gsub("\n",'').gsub("\r",'')
      elsif node.name == 'p' then
      
        puts "parse_node called on p: #{node.keys}"
        
        if node["class"] then
          puts node["class"]
          @metadata[:start_quote_strings].each do |bq|
            if node["class"].include? bq then
              @_margin = 1.0
              puts "New Margin From Class is: #{@_margin}"
            end
          end
          
          @metadata[:end_quote_strings].each do |eq|
            if node["class"].include? eq then
              @_margin = 0.0
              puts "New Margin From Class is: #{@_margin}"
            end
          end
        end # end if node class
        
        if node["style"] then
          puts node["style"]
          rules = node["style"].scan(/([\w\-]+)\s*\:\s*([\d\.]+)/)
          if rules then
            rules.each do |rule|
              if rule[0] == 'margin-left' then
                @_margin = rule[1].to_f
                puts "New Margin is: #{@_margin}"
              end
              if rule[0] == 'margin' then
                @_margin = rule[1].to_f
                puts "New Margin is: #{@_margin}"
              end
            end # end rules.each
          end
        end # end if node style
        text = Sanitize.clean(node.to_s, :elements => ['b','i','em','strong','code','br','img'], :attributes => { 'img' => ['src', 'alt'] })
        if not text.include? "{: .H" then
          text.gsub!("\n",' ')
          text.gsub!("\r",' ')
        end
        text = to_kramdown(text)
        if @_margin > 0.0 then
          text = "> #{text}\n>\n"
        else
          text = "\n#{text}\n\n"
        end
      # end elsif node.name == 'p'
      else
        puts "parse_node called on: #{node.name} with #{node.keys}"
        text = to_kramdown(node.to_s)
      end
      
      return text
    end # end parse_node
    def to_kramdown(text)
       i = 0
      while i < @@_clean.length - 1
        text.gsub!(@@_clean[i],@@_clean[i+1].downcase)
        text.gsub!(@@_clean[i].downcase,@@_clean[i+1].downcase) if @@_clean[i].respond_to? :downcase
        i += 2
      end
      ['*','_'].each do |es|
        text.gsub!(es,"\\#{es}")
      end
      [['i','_'],['b','**'],['strong', '**'],['br',"\n"]].each do |t|
        text.gsub!("<#{t[0]}>",t[1])
        text.gsub!("</#{t[0]}>",t[1])
        text.gsub!("<#{t[0]}/>",t[1])
        text.gsub!("<#{t[0]} />",t[1])
      end
      # anything we didn't get by now, we ain't gonna get.
      text = Sanitize.clean(text)
      return text
    end
  end # end book processor
end

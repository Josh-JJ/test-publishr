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

  class Project
    def initialize(absolutepath, language=nil, absoluteconverterspath='', rails_resources_url='', book_source_file_path='', projectname='unnamed')
      @name = projectname
      if language and not language.empty?
        @language = language.include?('.') ? language : ".#{language}" # inside of the whole publishr gem, @language must be prefixed with a dot
      else
        @language = nil
      end
      @inpath = absolutepath
      @converterspath = absoluteconverterspath
      @rails_resources_url = rails_resources_url
      @book_source_file_path = book_source_file_path
      @gempath = Publishr::Project.gempath
      @metadata = YAML::load(File.open(File.join(@inpath,"metadata#{@language}.yml"), 'r').read) if File.exists?(File.join(@inpath,"metadata#{@language}.yml"))
    end

    def self.gempath
      File.expand_path('../../../', __FILE__)
    end

    def make_ebook
      ebook = EbookRenderer.new(@inpath, @metadata, @language, @rails_resources_url, @name)
      ebook.render
      if @converterspath and File.exists?(File.join(@converterspath,'kindlegen'))
        kindlegen = File.join(@converterspath,'kindlegen')
        epubfile = File.join(@inpath,"#{ @name }#{ @language }.epub")
        lines = []
        IO.popen("#{ kindlegen } -verbose #{ epubfile }") do |io|
          while (line = io.gets) do
            puts line
            lines << line
          end
        end
        lines.join('<br />')
      else
        puts 'path to kindlegen was not specified or binary not present. Not generating a Kindle .mobi file.'
      end
    end

    def make_pdf
      pdf = LatexRenderer.new(@inpath, @metadata, @language)
      pdf.render

      outpath = File.join(@inpath,'latex')

      Dir.chdir outpath
      Dir['*.eps'].each do |f|
        `perl /usr/bin/epstopdf #{ f }`
        jpg_to_delete = File.basename(f).gsub(/(.*).eps/, '\1.jpg')
        FileUtils.rm jpg_to_delete if File.exists? jpg_to_delete
        FileUtils.rm f
      end

      # Dir[File.join(outpath,'*.jpg')].each do |infilepath|
      #   `convert #{infilepath} -colorspace CMYK #{infilepath}`
      # end

      # pdflatex handles jpg files directly, so the following is no longer needed
      # binaryfile = File.join(@converterspath,'jpeg2ps 2>&1')
      # Dir[File.join(outpath,'*.jpg')].each do |infilepath|
      #   outfilepath = File.join(outpath, File.basename(infilepath).gsub(/(.*).jpg/, '\1.eps'))
      #   `#{ binaryfile } -r 0 -o #{ outfilepath } #{ infilepath }`
      #   `perl /usr/bin/epstopdf --nocompress --nogs #{ outfilepath }`
      #   FileUtils.rm infilepath
      # end

      `makeindex main#{ @language }.idx`
      lines = []
      IO.popen("pdflatex -interaction=nonstopmode main#{ @language }.tex 2>&1") do |io|
        while (line = io.gets) do
          puts line
          lines << line
        end
      end

      FileUtils.mv(File.join(outpath,"main#{ @language }.pdf"), File.join(@inpath,"#{ @name }#{ @language }.pdf")) if File.exists?(File.join(outpath,"main#{ @language }.pdf"))
      lines.join('<br />')
    end

    def make_web
      Dir.chdir @inpath
      #FileUtils.rm_rf 'out'
      site = Webgen::Website.new '.'
      site.init
      messages = site.render
      #FileUtils.rm_rf '.sass-cache'
      #FileUtils.rm_rf 'webgen.cache'
      `#{@gempath}/lib/webgen_postprocessing.sh out`
      configfile = File.join(@inpath, '.publishr_config')
      if File.exists?(configfile)
        config = YAML::load(File.read(configfile))
        if config[:web_documentroot_copy] == true
          FileUtils.mkdir_p(config[:web_documentroot_path])
          FileUtils.cp_r(File.join(@inpath, 'out'), config[:web_documentroot_path])
        end
      end
      messages
    end

    def convert_book
      Dir.chdir @inpath
      source_html = File.open(@book_source_file_path, 'r'){ |f| f.read }
      Publishr::BookProcessor.new(@inpath, @metadata).import(source_html)
    end
    
    def make_images_local(kramdown)
      images = []
      processed_lines = []
      kramdown.split("\n").each do |line|
        match = /\!\[.*?\]\((.*?)\)/.match(line)
        images << match[1] if match
        processed_lines << line.gsub(/\!\[(.*?)\]\((.*?)\)/){ "![#{ $1 }](#{ File.basename($2) })" }
      end
      FileUtils.mkdir_p File.join(@inpath,'images')
      FileUtils.chdir File.join(@inpath,'images')
      output = ["The following files were downloaded into the image folder of your document:\n"]
      images.each do |image|
        FileUtils.rm_f File.join(@inpath,'images',File.basename(image))
        output << `wget -nv #{image} 2>&1`
      end
      return processed_lines.join("\n"), output
    end
      

  end
end

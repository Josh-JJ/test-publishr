PublishR
=================

This is a rapid publishing processor for ebooks (MOBI format for Amazon Kindle, EPUB format for other ebook readers), for real books (PDF via LaTeX) and the web (staic webpages via webgen).

This processor harnesses the publishing powers of LaTeX, Kramdown and Webgen and adds proven ebook compilation algorithms to the mix.

PublishR is a command line publishing platform allowing users to efficiently render a content source into several different output formats.

The author of this Gem, Red (E) Toold Ltd., provides a [convenient web-based frontend](http://red-e.eu/app/publishr) for it (also named Publishr), adding the version management and collaboration powers of git to the mix.

All output formats are generated only from *one* well structured file system consisting of plain-text kramdown files, images, and configuration files, thereby saving any conversion work between output formats. Further, since there is only one text source, changes to this text propagate directly to all output formats, thereby saving work on keeping many formats up-to-date.

With PublishR you can handle voluminous books with the same ease as short articles. PublishR uses one of the world's best typesetting programs, LaTeX, as a backend for generating PDFs.

For ebooks, it uses its own algorithms for generating optimized Kindle HTML code, a cover page, copyright page, title page, table of contents, footnotes and Kindle-optimized navigation, all wrapped into one MOBI file with Amazon's proprietary converter.

Static webpages are generated with help of the `webgen` gem.

PublishR can also convert plain HTML text and messy HTML code exported from poular word processors. This allows clean and rapid re-publishing of all kinds of information sources.

PublishR (like LaTeX) is based on the idea that authors should be able to focus on the content of what they are writing without being distracted by its visual presentation. In preparing a PublishR document, the author specifies the logical structure using familiar concepts such as chapter, headings, quotes, footnotes, images, etc. (utilizing [kramdown](http://kramdown.rubyforge.org/) markup) and lets the publishing system worry about the presentation of these structures. It therefore encourages the separation of layout from content while still allowing manual typesetting adjustments where needed.

PublishR has been developed in collaboration with a publishing company and hundreds of PublishR-generated Kindle and real-paper books have already been published and sold.

IMPORTANT NOTE
--------------

We are a small developer team and keeping tons of documentation up to date is not an easy task. If you run into problems, please [contact us](http://red-e.eu) personally, we will gladly help you and update the documentation for you.

HOW TO USE
----------

`gem install publishr`

For PDF generation, you also need to install LaTeX:

`apt-get install texlive-full`

Prepare a required "source directory". To get started, clone the example source directory from https://github.com/michaelfranzl/PublishR/tree/master/lib/document_skeleton. If you run publishr against this directory, it will produce all possible output formats successfully.

The command line syntax is

`publishr SOURCEPATH FORMAT LANGUAGE (CONVERTERSPATH)`

where

SOURCEPATH: Mandatory. Absolute path to the source directory. For the FORMAT `pdf` and `ebook` you have to include `/src` in the path. For the FORMAT `web` you must not append `/src`.

FORMAT: Mandatory. Specifies the ouput format you want to generate. Valid options are `ebook`, `pdf` and `web`.

LANGUAGE: Mandatory. Specifies an arbitrary language string. In SOURCEPATH, all required files for an the output format FORMAT must have this language string as part of their filename. Use `en` if you experiment with the document example hosted at https://github.com/michaelfranzl/PublishR/tree/master/lib/document_skeleton

CONVERTERSPATH: Optional. An absolute directory path which must contain Amazon's propritary binary `kindlegen`, which Amazon provides for free at the point of this writing. If not present, an EPUB file is still generated but no Kindle MOBI is generated.
  

OUTPUT FILE FORMAT
------------------

The output files are as follows, depending on the `FORMAT` parameter. The output directory is SOURCEPATH.

`ebook`
: `unnamed.LANGUAGE.epub` and `unnamed.LANGUAGE.mobi`

`pdf`
: `unnamed.LANGUAGE.pdf`

`web`
: A directory named `out` will be generated next to the `src` directory. Please refer to the documentation of the Gem `webgen` to understand more fully.


FULL DOCUMENTATION
--------------------------

The abilities of this Gem and the source directory structure are documented in full at [http://documentation.red-e.eu/publishr](http://documentation.red-e.eu/publishr), even though this documentation also mentions our user-friendly web-based frontend for this Gem (see [http://red-e.eu/app/publishr](http://red-e.eu/app/publishr) for more information). The documentation is so exhaustive that we won't include it here again.


LICENSE
-------

PublishR -- Rapid publishing for ebooks (epub, Kindle), paper (LaTeX) and the web (webgen)'
Copyright (C) 2012 Red (E) Tools Ltd. (www.red-e.eu)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
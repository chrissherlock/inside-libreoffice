# pandoc is needed to generate odt and pdf
# title and author comes from header.md
pandoc --toc `cat toc.txt` -o inside-libreoffice.odt
pandoc --toc `cat toc.txt` -o inside-libreoffice.pdf

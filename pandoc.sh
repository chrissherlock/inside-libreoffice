# pandoc is needed to generate inside-linux.odt
pandoc --toc -V title:"Inside LibreOffice" -V author:"Chris Sherlock" `cat toc.txt` -o inside-linux.odt

INFILES = EF270C14-6C6A-4436-BB38-6B075B2217B0.png \
	  erricon.png \
	  icon.png \
	  icons/* \
	  icons/fancy/* \
	  info.plist \
	  todo.pl

OUTFILE = Alfred-TODO.alfredworkflow

$(OUTFILE): $(INFILES)
	$(RM) $(OUTFILE)
	zip $@ $(INFILES)

install: $(OUTFILE)
	open $(OUTFILE)

clean:
	$(RM) $(OUTFILE)

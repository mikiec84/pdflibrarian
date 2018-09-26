bin_SCRIPTS = \
	pre-inst/pdf-lbr-edit-bib \
	pre-inst/pdf-lbr-import-pdf \
	pre-inst/pdf-lbr-query-ads \
	pre-inst/pdf-lbr-read-bib \
	pre-inst/pdf-lbr-rebuild \
	pre-inst/pdf-lbr-remove-pdf \
	$(END_OF_LINE)

pkgperllib_DATA = \
	pre-inst/config.pm \
	src/bibtex.pm \
	src/library.pm \
	src/query_dialog.pm \
	src/util.pm \
	$(END_OF_LINE)

xslt_DATA = \
	src/bibtex.xsl \
	src/dublincore.xsl \
	$(END_OF_LINE)

EXTRA_DIST = \
	$(DATA) \
	debian/changelog \
	debian/compat \
	debian/control \
	debian/copyright \
	debian/rules \
	debian/source/
	$(END_OF_LINE)

BUILT_SOURCES = \
	debian/control \
	$(END_OF_LINE)

debian/control: debian/control.in Makefile
	$(AM_V_GEN)$(SED) 's|[@]DEPENDS[@]|$(DEPENDS)|g' $< > $@

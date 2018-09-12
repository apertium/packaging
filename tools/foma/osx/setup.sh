perl -pe 's@^prefix = /usr/local@prefix = \$(DESTDIR)/usr/local@g;' -i Makefile

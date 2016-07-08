STATICPERLRC=$(shell readlink -m staticperl.rc)
export STATICPERLRC

SP=$(shell readlink -m ../local/bin/staticperl)

CC=$(shell readlink -m ../musl/bin/musl-gcc)
PERL_CC=$(CC)

MODULES=strict\
		autodie\
		English\
		Errno\
		File::Spec\
		File::Copy\
		File::Path\
		Getopt::Long\
		HTTP::Tiny\
		if\
		JSON::Tiny\
		PerlIO\
		PerlIO::encoding\
		POSIX\
		Time::Local\
		version

MODULES_M=$(patsubst %, -M%, $(MODULES))

MUSL_SRC=musl-1.1.15
MUSL_INS=$(shell readlink -m musl)

all: vc3-pilot-static

vc3-pilot-static: $(MUSL_INS)/bin/musl-gcc
	-$(SP) install
	-$(SP) install
	$(SP) install
	$(SP) mkapp $@ --static --strip pod --boot ../../vc3-pilot-bare $(MODULES_M)
	strip $@

$(MUSL_INS)/bin/musl-gcc: $(MUSL_SRC)/README
	cd $(MUSL_SRC) && ./configure --prefix=$(MUSL_INS) --disable-shared --enable-static
	cd $(MUSL_SRC) && make
	cd $(MUSL_SRC) && make install

$(MUSL_SRC)/README: $(MUSL_SRC).tar.gz 
	tar zxpf $^

$(MUSL_SRC).tar.gz:
	wget http://download.virtualclusters.org/repository/$@

.PHONY: clean distclean

clean:
	-rm vc3-pilot-static

distclean:
	-rm -rf musl* build





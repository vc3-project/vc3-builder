PERL5LIB=$(shell readlink -m ../fatlib)
export PERL5LIB

STATICPERLRC=$(shell readlink -m staticperl.rc)
export STATICPERLRC

SP=$(shell readlink -m ../local/bin/staticperl)

CC=$(shell readlink -m ../musl/bin/musl-gcc)
PERL_CC=$(CC)

BARE=../../vc3-builder

COREMODULES=strict warnings English constant overload Tie::RefHash File::Copy File::Temp File::stat FindBin Encode POSIX if locale File::Glob integer Sys::Hostname IO::Socket base Time::Local PerlIO encoding Time::gmtime
EXTRAMODULES=Net::SSLeay IO::Socket::SSL
MODULES_M=$(patsubst %, -M%, $(COREMODULES)) $(patsubst %, -M%, $(EXTRAMODULES))

MUSL_SRC=musl-1.1.15
MUSL_INS=$(shell readlink -m musl)

all: vc3-builder-static

vc3-builder-static: $(MUSL_INS)/bin/musl-gcc $(BARE) $(STATICPERLRC) Makefile
	-$(SP) install
	-$(SP) install
	$(SP) install
	$(SP) mkapp $@ --static --strip pod --boot $(BARE) $(MODULES_M)
	#$(SP) mkapp $@ --static --strip pod --boot $(BARE) $(MODULES_M) -Mstrict -Mwarnings -MEnglish -Mconstant
	#$(SP) mkapp $@ --static --strip pod --boot $(BARE) $(MODULES_M) -Mstrict -Mwarnings -MEnglish -MGetopt::Long -MLockFile::Simple -MDigest::Perl::MD5
    # -Mstrict -MEnglish -MGetopt::Long -MTie::RefHash 
	strip $@

$(MUSL_INS)/bin/musl-gcc: | $(MUSL_SRC)
	cd $(MUSL_SRC) && ./configure --prefix=$(MUSL_INS) --disable-shared --enable-static
	cd $(MUSL_SRC) && make
	cd $(MUSL_SRC) && make install

$(MUSL_SRC): | $(MUSL_SRC).tar.gz
	tar zxpf $(MUSL_SRC).tar.gz

$(MUSL_SRC).tar.gz:
	curl -o "$@" -z "$@" https://s3.ssl-hep.org/vc3-repository-70e707f3-6df8-41f6-adb2-fa5ecba1548d/builder-files/$@

.PHONY: clean distclean

clean:
	-rm vc3-builder-static

distclean:
	-rm -rf musl* build





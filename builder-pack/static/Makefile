PERL5LIB=$(shell readlink -m ../fatlib)
export PERL5LIB

STATICPERLRC=$(shell readlink -m staticperl.rc)
export STATICPERLRC

SP=$(shell readlink -m ../local/bin/staticperl)

export CC=musl-gcc
export PERL_CC=$(CC)
export OPENSSL_PREFIX=$(VC3_ROOT_OPENSSL_STATIC)

BARE=../../vc3-builder

COREMODULES=strict warnings English constant overload Tie::RefHash File::Copy File::Temp File::stat FindBin Encode POSIX if locale File::Glob integer Sys::Hostname IO::Socket base Time::Local PerlIO encoding Time::gmtime
COREMODULES_M=$(patsubst %, -M%, $(COREMODULES))
EXTRAMODULES=Net::SSLeay IO::Socket::SSL
EXTRAMODULES_M=$(patsubst %, -M%, $(EXTRAMODULES))

all: vc3-builder-static

vc3-builder-static: $(BARE) $(STATICPERLRC) Makefile perl modules
	$(SP) mkapp $@ --static --strip pod --boot $(BARE) $(COREMODULES_M) $(EXTRAMODULES_M)
	strip $@

modules: $(STATICPERLRC) Makefile perl
	$(SP) instcpan Net::SSLeay
	$(SP) instcpan IO::Socket::SSL
	chmod u+w build/perl/lib/auto/Net/SSLeay/extralibs.ld
	echo " -ldl" >> build/perl/lib/auto/Net/SSLeay/extralibs.ld
	echo " $${VC3_ROOT_MUSL_ZLIB}/lib/libz.a" >> build/perl/lib/auto/Net/SSLeay/extralibs.ld

perl: $(STATICPERLRC) Makefile
	-$(SP) install
	-$(SP) install
	$(SP) install

.PHONY: clean distclean

clean:
	-rm vc3-builder-static

distclean:
	-rm -rf build





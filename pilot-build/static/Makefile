PERL5LIB=$(shell readlink -m ../fatlib)
export PERL5LIB

STATICPERLRC=$(shell readlink -m staticperl.rc)
export STATICPERLRC

SP=$(shell readlink -m ../local/bin/staticperl)

CC=$(shell readlink -m ../musl/bin/musl-gcc)
PERL_CC=$(CC)

BARE=../../vc3-pilot-bare

MODULES=$(shell PERL5LIB=$(PERL5LIB) $(BARE) --debug-modules-used)

MODULES_M=$(patsubst %, -M%, $(MODULES))

MUSL_SRC=musl-1.1.15
MUSL_INS=$(shell readlink -m musl)

all: vc3-pilot-static

vc3-pilot-static: $(MUSL_INS)/bin/musl-gcc $(BARE)
	-$(SP) install
	-$(SP) install
	$(SP) install
	$(SP) mkapp $@ --static --strip pod --boot $(BARE) $(MODULES_M)
	strip $@

$(MUSL_INS)/bin/musl-gcc: | $(MUSL_SRC)
	cd $(MUSL_SRC) && ./configure --prefix=$(MUSL_INS) --disable-shared --enable-static
	cd $(MUSL_SRC) && make
	cd $(MUSL_SRC) && make install

$(MUSL_SRC): | $(MUSL_SRC).tar.gz
	tar zxpf $(MUSL_SRC).tar.gz

$(MUSL_SRC).tar.gz:
	curl -o "$@" -z "$@" http://download.virtualclusters.org/repository/$@

.PHONY: clean distclean

clean:
	-rm vc3-pilot-static

distclean:
	-rm -rf musl* build





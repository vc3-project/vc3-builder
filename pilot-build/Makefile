PERL5LIB=$(CURDIR)/local/lib/perl5:$(CURDIR)/fatlib
export PERL5LIB

FATPACKER=$(CURDIR)/local/bin/fatpack

all: vc3-pilot

vc3-pilot: ../vc3-pilot-bare
	$(FATPACKER) file $^ -bare > $@ 
	@chmod 755 $@
	@echo generated $@

.PHONY: clean

clean:
	-rm vc3-pilot


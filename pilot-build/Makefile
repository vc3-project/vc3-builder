PERL5LIB=$(CURDIR)/local/lib/perl5:$(CURDIR)/fatlib
export PERL5LIB

FATPACKER=$(CURDIR)/local/bin/fatpack

all: vc3_pilot_job

vc3_pilot_job: ../vc3_pilot_job-bare
	$(FATPACKER) file $^ -bare > $@ 
	@chmod 755 $@
	@echo generated $@

.PHONY: clean

clean:
	-rm vc3_pilot_job


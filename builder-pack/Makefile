PERL5LIB=$(CURDIR)/local/lib/perl5:$(CURDIR)/fatlib
export PERL5LIB

BARE=../vc3-builder-bare
FATPACKER=$(CURDIR)/local/bin/fatpack

MODULES=$(shell ./find_modules_needed)
MODULES_DIR=$(shell echo $(MODULES) | xargs -n1 | sed -e 's^::^/^g;s/$$/.pm/')

all: vc3-builder

vc3-builder: $(BARE) | fatlib
	$(FATPACKER) file $^ -bare > $@ 
	echo >> $@
	echo 'package VC3::Pilot;' >> $@
	echo '__DATA__' >> $@
	cat ../vc3-catalog.json >> $@
	@chmod 755 $@
	@echo generated $@

fatlib:
	#for module in $(MODULES); do cpanm --reinstall -Llocal -nq $${module}; done
	#cd fatlib local/lib/perl5 && for file in $(MODULES_DIR); do ln -sf ../local/lib/perl5/$${file}; done

.PHONY: clean

clean:
	-rm vc3-builder


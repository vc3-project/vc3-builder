PERL5LIB=$(CURDIR)/local/lib/perl5:$(CURDIR)/fatlib
export PERL5LIB

BARE=../vc3-builder-bare
FATPACKER=$(CURDIR)/local/bin/fatpack

MODULES=$(shell ./find_modules_needed)
MODULES_DIR=$(shell echo $(MODULES) | xargs -n1 | sed -e 's^::^/^g;s/$$/.pm/')

RECIPES_DIR=../recipes
RECIPES=$(shell find $(RECIPES_DIR) -name "*.json" | sort) 

all: vc3-builder

vc3-builder: $(BARE) $(shell find ../recipes/ -name '*.json') $(shell find fatlib/VC3/ -name '*.pm') | fatlib
	@$(FATPACKER) file $^ -bare > $@ 
	@sed -i $@ -e '2s/^/#\n# This is an automatically generated file. Do not modify! All changes\n# should go into vc3-builder-bare and the modules in VC3.\n#\n# Copyright (C) 2016- The University of Notre Dame\n# This software is distributed under the GNU General Public License.\n# See the file COPYING for details.\n# \n/' 


	@echo >> $@
	@echo 'package VC3::Builder;' >> $@
	@echo '__DATA__' >> $@
	@echo '[' >> $@
	@sep=''; for r in $(RECIPES); do echo $${sep} >> $@; cat $${r} >> $@; sep=','; done
	@echo ']' >> $@
	@chmod 755 $@
	@echo generated $@

fatlib-install:
	for module in $(MODULES); do cpanm --reinstall -Llocal -nq $${module}; done
	cd fatlib local/lib/perl5 && for file in $(MODULES_DIR); do ln -sf ../local/lib/perl5/$${file}; done

.PHONY: clean

clean:
	-rm vc3-builder


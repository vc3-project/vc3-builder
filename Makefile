all: vc3-builder

vc3-builder: vc3-builder-bare vc3-catalog.json VC3 $(shell find VC3 -name '*.pm')
	$(MAKE) -C builder-pack vc3-builder
	mv builder-pack/vc3-builder .

static: vc3-builder-static

vc3-builder-static: vc3-builder
	$(MAKE) -C builder-pack/static vc3-builder-static
	cp builder-pack/static/vc3-builder-static $@

builder-pack/static/vc3-builder-static: vc3-builder-bare
	$(MAKE) -C builder-pack/static vc3-builder-static

.PHONY: clean static

clean:
	-$(MAKE) -C builder-pack clean
	-$(MAKE) -C builder-pack/static clean
	-rm -rf vc3-builder vc3-builder-static


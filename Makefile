all: vc3-builder

vc3-builder:
	$(MAKE) -C builder-pack vc3-builder
	cp builder-pack/vc3-builder .

static: vc3-builder-static

vc3-builder-static: vc3-builder
	$(MAKE) -C builder-pack/static vc3-builder-static
	cp builder-pack/static/vc3-builder-static $@

builder-pack/static/vc3-builder-static: vc3-builder-bare
	$(MAKE) -C builder-pack/static vc3-builder-static

.PHONY: vc3-builder clean static

clean:
	-$(MAKE) -C builder-pack clean
	-$(MAKE) -C builder-pack/static clean
	-rm -rf vc3-builder vc3-builder-static


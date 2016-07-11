all: vc3-pilot

vc3-pilot: vc3-pilot-bare
	$(MAKE) -C pilot-build vc3-pilot
	mv pilot-build/vc3-pilot .

static: vc3-pilot-static


vc3-pilot-static: pilot-build/static/vc3-pilot-static
	cp $^ $@

pilot-build/static/vc3-pilot-static: vc3-pilot-bare
	$(MAKE) -C pilot-build/static vc3-pilot-static

.PHONY: clean static

clean:
	-$(MAKE) -C pilot-build clean
	-$(MAKE) -C pilot-build/static clean
	-rm -rf vc3-pilot


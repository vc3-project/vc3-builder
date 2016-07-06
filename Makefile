all: vc3-pilot

vc3-pilot: vc3-pilot-bare
	$(MAKE) -C pilot-build vc3-pilot
	mv pilot-build/vc3-pilot .

.PHONY: clean

clean:
	-$(MAKE) -C pilot-build clean
	-rm -rf vc3-pilot


all: vc3_pilot_job

vc3_pilot_job: vc3_pilot_job-bare
	$(MAKE) -C pilot-build vc3_pilot_job
	mv pilot-build/vc3_pilot_job .

.PHONY: clean

clean:
	-$(MAKE) -C pilot-build clean
	-rm -rf vc3_pilot_job


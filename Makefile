NODE ?= node
DEVICE ?= dev1
DATE ?= $(shell date -u +%Y-%m-%d)
EVENT_ID ?=
THING ?=
EXPIRES ?= 900

.PHONY: r2-apply-lifecycle presign-put presign-get demo-index-day validate-schemas

r2-apply-lifecycle:
	@./scripts/config_r2.sh

presign-put:
	@if [ -z "$(THING)" ] || [ -z "$(EVENT_ID)" ]; then \
		echo "Usage: make presign-put THING=thumb|clip EVENT_ID=evt-... [DEVICE=dev1] [EXPIRES=900]"; \
		exit 1; \
	fi
	@$(NODE) backend/presign_put.js --device $(DEVICE) --event $(EVENT_ID) --thing $(THING) --expires $(EXPIRES)

presign-get:
	@if [ -z "$(THING)" ] || [ -z "$(EVENT_ID)" ]; then \
		echo "Usage: make presign-get THING=thumb|clip EVENT_ID=evt-... [DEVICE=dev1] [EXPIRES=900]"; \
		exit 1; \
	fi
	@$(NODE) backend/presign_get.js --device $(DEVICE) --event $(EVENT_ID) --thing $(THING) --expires $(EXPIRES)

demo-index-day:
	@$(NODE) tools/demo-index-day.js --device $(DEVICE) --date $(DATE) --out schemas/samples/day-$(DATE).json $(if $(META),$(foreach m,$(META),--meta $(m)),)

validate-schemas:
	cd schemas && npm test

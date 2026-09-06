# psychedelic-platformer — prototype runner.
# Every prototype under prototypes/ is a standalone Godot project.
# Usage: make run P=02

GODOT ?= godot
PROTOTYPES := $(notdir $(wildcard prototypes/*))
P ?=

# Resolves "02" (or "02-unreliable-vision") to the full folder name.
DIR = $(firstword $(filter $(P)%,$(PROTOTYPES)))

.PHONY: help list run edit clean check

help: ## Show this help
	@echo "psychedelic-platformer"
	@echo
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  %-8s %s\n", $$1, $$2}'
	@echo
	@echo "  P=<n>    prototype to act on, e.g. P=02"
	@echo "  GODOT=   path to the Godot 4 binary (default: godot)"

list: ## List the prototypes and their questions
	@for d in $(PROTOTYPES); do \
		printf "  %-26s %s\n" "$$d" "$$(sed -n 's/^\*\*Question:\*\* *//p' prototypes/$$d/README.md | head -1)"; \
	done

check:
	@test -n "$(P)" || { echo "set P=<prototype>, e.g. make run P=02"; exit 1; }
	@test -n "$(DIR)" || { echo "no prototype matches '$(P)'. try: make list"; exit 1; }
	@command -v $(GODOT) >/dev/null 2>&1 || { echo "godot not found. set GODOT=/path/to/godot"; exit 1; }

run: check ## Run a prototype (P=02)
	$(GODOT) --path prototypes/$(DIR)

edit: check ## Open a prototype in the Godot editor (P=02)
	$(GODOT) --editor --path prototypes/$(DIR)

clean: ## Drop the Godot import caches
	rm -rf prototypes/*/.godot prototypes/*/.import

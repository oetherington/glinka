.PHONY: integration
all: debug
debug:
	@zig build
release:
	@zig build -Drelease-fast=true
test:
	@zig build test
run: integration
integration:
	@npm run integration
lint:
	@zig fmt --check src/**/*.zig
coverage:
	@zig test test.zig --test-cmd kcov --test-cmd kcov-output --test-cmd --include-pattern=src --test-cmd-bin
memcheck:
	drmemory -results_to_stderr -exit_code_if_errors 1 -show_reachable -- ./zig-out/bin/glinka integration/tests/types.ts >> /dev/null

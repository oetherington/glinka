all:
	@zig build
release:
	@zig build -Drelease-fast=true
run:
	@echo
	@zig build run -- examples/example_1.ts
	@echo
test:
	@zig build test
integration:
	@npm run integration
lint:
	@zig fmt --check src/**/*.zig
coverage:
	@zig test test.zig --test-cmd kcov --test-cmd kcov-output --test-cmd --include-pattern=src --test-cmd-bin

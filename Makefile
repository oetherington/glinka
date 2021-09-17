all:
	@zig build
release:
	@zig build -Drelease-fast=true
run:
	@echo
	@zig build run
	@echo
test:
	@zig build test
coverage:
	@zig test test.zig --test-cmd kcov --test-cmd kcov-output --test-cmd --include-pattern=src --test-cmd-bin

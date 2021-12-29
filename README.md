# Glinka

![CI Workflow Status](https://github.com/oetherington/glinka/actions/workflows/ci.yml/badge.svg)

Glinka is a Typescript compiler written in Zig designed for speed. Please note
that it is still a work in progress and large portions of the language are not
yet implemented. For a general overview of what's already available you can look
in the `examples` directory and at the `TODO` file.

### Building

 > :warning: **Important note for Windows users**: You must clone the
   repository with git's `autocrlf` setting disabled. You can do this globally
   by running `git config --global core.autocrlf false` before cloning, or just
   for glinka by cloning with `git clone --config core.autocrlf=false`. See
   [this issue](https://github.com/ziglang/zig/issues/9257) for more
   information.

Create a debug build: `make`.

Create a production build: `make release`.

Run the tests: `make test`.

Create a coverage report (requires `kcov` to be installed): `make coverage`.

### Contributing

Pull requests and bug reports are welcome
[on Github](https://github.com/oetherington/glinka).

Contributors should follow the
[Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

### Copying

Glinka is free-software under the
[GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html) (see the included
`COPYING` file for more information).

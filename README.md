# AMDB

[![Project Status: WIP - Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](http://www.repostatus.org/badges/latest/wip.svg)](http://www.repostatus.org/#wip)
[![Build Status](https://travis-ci.org/tpapp/AMDB.jl.svg?branch=master)](https://travis-ci.org/tpapp/AMDB.jl)
[![Coverage Status](https://coveralls.io/repos/tpapp/AMDB.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/tpapp/AMDB.jl?branch=master)
[![codecov.io](http://codecov.io/github/tpapp/AMDB.jl/coverage.svg?branch=master)](http://codecov.io/github/tpapp/AMDB.jl?branch=master)

Loose collection of functions and some basic infrastructure for working with the AMDB files. For internal use at the IHS.

## Installation

Requires Julia `v0.6`. Some dependencies are unregistered, so install as
```julia
Pkg.clone("https://github.com/tpapp/RaggedData.jl.git")
Pkg.clone("https://github.com/tpapp/ByteParsers.jl.git")
Pkg.clone("https://github.com/tpapp/DiscreteRanges.jl.git")
Pkg.clone("https://github.com/tpapp/LargeColumns.jl.git")
Pkg.clone("https://github.com/tpapp/FlexDates.jl.git")
Pkg.clone("https://github.com/tpapp/WallTimeProgress.jl.git")
Pkg.clone("https://github.com/tpapp/AMDB.jl.git")
```
## Usage

Needs the environment variable `AMDB_FILES`. Either
```shell
export AMDB_FILES=path/to/files
```
in your shell, or
```julia
ENV["AMDB_FILES"] = "path/to/files"
```
in your `~/.juliarc.jl`.

See the `scripts/` directory.

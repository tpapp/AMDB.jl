# AMDB_IHS
[![Project Status: WIP - Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](http://www.repostatus.org/badges/latest/wip.svg)](http://www.repostatus.org/#wip)
[![Build Status](https://travis-ci.org/tpapp/AMDB_IHS.jl.svg?branch=master)](https://travis-ci.org/tpapp/AMDB_IHS.jl)
[![Coverage Status](https://coveralls.io/repos/tpapp/AMDB_IHS.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/tpapp/AMDB_IHS.jl?branch=master)
[![codecov.io](http://codecov.io/github/tpapp/AMDB_IHS.jl/coverage.svg?branch=master)](http://codecov.io/github/tpapp/AMDB_IHS.jl?branch=master)

Loose collection of functions and some basic infrastructure for working with the AMDB files. For internal use at the IHS.

## Installation

Requires Julia `v0.6-`.

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

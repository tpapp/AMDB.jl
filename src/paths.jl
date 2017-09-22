"""
    $(SIGNATURES)

Return the directoy for the AMDB data dump.

The user should set the environment variable `AMDB_FILES`.
"""
function data_directory()
    key = "AMDB_FILES"
    @assert(haskey(ENV, key),
            "You should put the path to the raw files in ENV[$key].")
    normpath(expanduser(ENV[key]))
end

"""
    $(SIGNATURES)

Add `components` (directories, and potentially a filename) to the AMDB
data dump directory.
"""
data_path(components...) = joinpath(data_directory(), components...)

const VALID_YEARS = 2000:2016

"""
    $(SIGNATURES)

The path for the AMDB data dump file (gzip-compressed CSV) for a given
year. Example:

```julia
AMDB.data_file(2000)
```
"""
function data_file(year)
    @assert year ∈ VALID_YEARS "Year outside $(VALID_YEARS)."
    ## special-case two years combined
    yearnum = year ≤ 2014 ? @sprintf("%02d", year-2000) : "1516"
    data_path("mon_ew_xt_uni_bus_$(yearnum).csv.gz")
end

"""
    $(SIGNATURES)

"""
all_data_files() = unique(data_file.(VALID_YEARS))

"""
    $(SIGNATURES)

Return the AMDB column names for the data dump as a vector.
"""
function data_colnames()
    header = readlines(data_path("mon_ew_xt_uni_bus.cols.txt"))[1]
    split(header, ';')
end

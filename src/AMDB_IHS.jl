module AMDB_IHS

export
    amdb_files_directory,
    amdb_data_path,
    amdb_data_file,
    amdb_colnames

"""
    amdb_files_directory()

Return the directoy for the AMDB data dump.

The user should set the environment variable `AMDB_FILES`.
"""
function amdb_files_directory()
    key = "AMDB_FILES"
    @assert haskey(ENV, key) "You should put the path to the raw files in ENV[$key]."
    normpath(expanduser(ENV[key]))
end

"""
    amdb_data_path(components...)

Add `components` (directories, and potentially a filename) to the AMDB
data dump directory.
"""
amdb_data_path(components...) = joinpath(amdb_files_directory(), components...)

"""
    amdb_data_file(year)

The path for the AMDB data dump file (gzip-compressed CSV) for a given
year. Example:

```julia
amdb_data_file(2000)
```
"""
function amdb_data_file(year)
    @assert year ∈ 2000:2016 "Year outside the range provided."
    ## special-case two years combined
    yearnum = year ≤ 2014 ? @sprintf("%02d", year-2000) : "1516"
    amdb_data_path("mon_ew_xt_uni_bus_$(yearnum).csv.gz")
end

"""
    amdb_colnames()

Return the AMDB column names for the data dump as a vector.
"""
function amdb_colnames()
    header = readlines(amdb_data_path("mon_ew_xt_uni_bus.cols.txt"))[1]
    split(header, ';')
end

end # module

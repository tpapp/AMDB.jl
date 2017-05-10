module AMDB_IHS

export
    amdb_files_directory,
    amdb_data_file,
    amdb_colnames

function amdb_files_directory()
    key = "AMDB_FILES"
    @assert haskey(ENV, key) "You should put the path to the raw files in ENV[$key]."
    normpath(expanduser(ENV[key]))
end

function amdb_data_file(year)
    @assert year ∈ 2000:2016 "Year outside the range provided."
    joinpath(amdb_files_directory(), @sprintf("mon_ew_xt_uni_bus_%02d.csv.gz", year-2000))
end

function amdb_colnames()
    header = readlines(joinpath(amdb_files_directory(), "mon_ew_xt_uni_bus.cols.txt"))[1]
    split(header, ';')
end

end # module

######################################################################
# count the AM column status for AMDB by year. large runtime, save
# results at the end, processed by another file (count_AM_tabulate.jl)
######################################################################

using AMDB
using TranscodingStreams
using CodecZlib
using JLD
using DocStringExtensions

"""
    $(SIGNATURES)

Read lines from `io`, split them on `delim`, and call `f` on the resulting vector of strings.

`limit` is passed to `split`, and sets the maximum number of fields.

Output a `.` every `progress` lines when the latter is positive.

When `maxlines` > 0, stop after that many lines.
"""
function dofields(f, io;
                  progress = 1000000, limit = 0, delim = ';', maxlines = 0)
    line = 0
    while !eof(io)
        if isa(progress, Integer) && line % progress == 0
            print(".")
        end
        line += 1
        if maxlines > 0 && line ≥ maxlines
            break
        end
        f(split(readline(io), delim; limit = limit))
    end
end

"""
    $(SIGNATURES)

Open `filename`, and count the unique strings in column `col_index`.

`options` are passed to `dofields` as keyword parameters.
"""
function count_field(filename, col_index; options...)
    io = open(filename, "r")
    c = Dict{String,Int}()
    dofields(GzipDecompressionStream(io);
             limit = col_index + 1, delim = ';', options...) do fields
                 kind = fields[col_index]
                 c[kind] = get(c, kind, 0) + 1
             end
    close(io)
    c
end

"""
    $(SIGNATURES)

Count all unique occurrences of strings in the given column `colname` for each year. Return a dictionary with elements `year => counts`, where counts is a `string => count` pair.
"""
function count_field_by_year(colname)
    counts = Dict{Int,Dict{String,Int}}()
    colnames = AMDB.colnames()
    colindex = findfirst(colnames, colname)
    @assert colindex > 0 "column $(colname) not found"
    for year in AMDB.all_years()
        println("processing $(year)")
        counts[year] = count_field(AMDB.data_file(year), colindex)
    end
    counts
end

status_counts = count_field_by_year("AM")

save(joinpath(AMDB.files_directory(), "status_counts.jld"), "status_counts",
     status_counts)

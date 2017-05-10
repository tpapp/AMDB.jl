######################################################################
# count the AM column status for AMDB by year. large runtime, save
# results at the end, processed by another file (count_AM_tabulate.jl)
######################################################################

using AMDB_IHS
using Libz
using JLD

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

function count_field(filename, col_index; options...)
    io = open(filename, "r")
    c = Dict{String,Int}()
    dofields(ZlibInflateInputStream(io);
             limit = col_index + 1, delim = ';', options...) do fields
                 kind = fields[col_index]
                 c[kind] = get(c, kind, 0) + 1
             end
    close(io)
    c
end

status_counts = Dict{Int,Any}()
colnames = amdb_colnames()

for year in 2000:2014
    println("processing year $(year)")
    status_counts[year] = count_field(amdb_data_file(year), findfirst(colnames, "AM"))
    println("DONE")
end

save(joinpath(amdb_files_directory(), "status_counts.jld"), "status_counts", status_counts)

using AMDB
using ByteParsers
using JLD
using CodecZlib
using WallTimeProgress

import AMDB:
    data_file, all_data_files, data_path, # data paths
    narrowest_Int, to_narrowest_Int,      # narrowing integers
    FileErrors, log_error                 # error logging

######################################################################
# read whole file -- first pass
######################################################################

function accumulate_stream(io::IO, parser_id_am, individuals, ams, errors::FileErrors;
                           tracker_period = 10_000_000, max_lines = -1)
    tracker = WallTimeTracker(tracker_period; item_name = "line")
    while !eof(io) && (max_lines < 0 || count(tracker) < max_lines)
        line_content = readuntil(io, 0x0a)
        record = parsenext(parser_id_am, line_content, 1, UInt8(';'))
        if isparsed(record)
            id, am = unsafe_get(record)
            individuals[id] = get(individuals, id, 0) + 1 # individual Individuals
            push!(ams, am)                # AM status
        else
            log_error(errors, count(tracker), line_content, getpos(record))
        end
        increment!(tracker)
    end
end

function accumulate_file(filename, parser_id_am, individuals, ams; args...)
    io = GzipDecompressionStream(open(filename))
    errors = FileErrors(filename)
    accumulate_stream(io, parser_id_am, individuals, ams, errors; args...)
    errors
end

# if this part breaks, then colnames changes, rewrite
cols = AMDB.data_colnames()
@assert cols[1] == "PENR"
@assert cols[6] == "AM"

parser_id_am = Line(PositiveInteger(Int64),
                    Skip(), Skip(), Skip(), Skip(),
                    ViewBytes())

individuals = Dict{parsedtype(parser_id_am[1]),Int}()

ams = Set{parsedtype(parser_id_am[2])}()

error_io = open(data_path("first_pass_errors.txt"), "w")
println(error_io, "first pass started at $(Dates.now())")
for file in all_data_files()
    println("processing $file")
    err = accumulate_file(file, parser_id_am, individuals, ams)
    show(error_io, err)
end
close(error_io)

ids = to_narrowest_Int(collect(keys(individuals)))
counts = collect(values(individuals))
total_count = sum(counts)
Tcounts = narrowest_Int(0, total_count)         # narrower type (need to do arithmetic)
AM_keys = sort(copy.(collect(ams)), lt=lexless) # copy to avoid shared structure

save(data_path("first_pass.jld"),
     "ids", ids,
     "counts", Tcounts.(counts),
     "AM_keys", AM_keys)

using AMDB
using ByteParsers
using JLD
using Parameters

import AMDB:
    data_file, all_data_files, data_path, # data paths
    process_file,                         # file processing with parser
    narrowest_Int, to_narrowest_Int       # narrowing integers

######################################################################
# read whole file -- first pass
######################################################################

# if this part breaks, then column names changed, *rewrite*
cols = AMDB.data_colnames()
@assert cols[1] == "PENR"
@assert cols[6] == "AM"

struct FirstPass{T1,T2}
    individuals::Dict{T1, Int}  # counts of individuals
    AMs::Set{T2}                # labor market spells ("Arbeitsmarkt")
end

function (f::FirstPass)(record)
    id, AM = record
    @unpack individuals, AMs = f
    individuals[id] = get(individuals, id, 0) + 1 # individual Individuals
    push!(AMs, AM)                                # AM status
end

# convenience constructor
FirstPass(parser::Line) =
    FirstPass(Dict{parsedtype(parser[1]),Int}(), Set{parsedtype(parser[2])}())

parser_id_am = Line(PositiveInteger(Int64),
                    Skip(), Skip(), Skip(), Skip(),
                    ViewBytes())

fp = FirstPass(parser_id_am)

error_io = open(data_path("first_pass_errors.txt"), "w")
println(error_io, "first pass started at $(Dates.now())")
for file in all_data_files()
    println("processing $file")
    err = process_file(file, parser_id_am, fp)
    show(error_io, err)
end
close(error_io)

ids = to_narrowest_Int(collect(keys(fp.individuals)))
counts = collect(values(fp.individuals))
total_count = sum(counts)
Tcounts = narrowest_Int(0, total_count) # narrower type (need to do arithmetic)
AM_keys = sort(copy.(collect(fp.AMs)), lt=lexless) # copy to avoid shared structure

save(data_path("first_pass.jld"),
     "ids", ids,
     "counts", Tcounts.(counts),
     "AM_keys", AM_keys)

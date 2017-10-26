using AMDB
using ByteParsers
using DiscreteRanges
using JLD
using LargeColumns
using RaggedData

import AMDB:
    process_file,                         # file processing with parser
    AutoIndex

######################################################################
# read whole file -- first pass
######################################################################

# if this part breaks, then column names changed, *rewrite*
cols = AMDB.data_colnames()
@assert cols[1] == "PENR"
@assert cols[6] == "AM"

mutable struct FirstPass{Tid, TAM, TAM_ix, Tsink}
    id_counter::RaggedCounter{Tid, Int32}
    AMs::AutoIndex{TAM, TAM_ix} # labor market spells ("Arbeitsmarkt")
    sink::Tsink
end

# convenience constructor
function FirstPass(parser::Line, dir)
    FirstPass(RaggedCounter(Int32, Int32),
              AutoIndex{Vector{UInt8}, Int8}(),
              SinkColumns(dir, Tuple{Int32, Int8, DiscreteRange{AMDB_Date}}))
end

function (fp::FirstPass{Tid, TAM, TAM_ix, TIO})(record) where {Tid,TAM,TAM_ix,TIO}
    id_wide, date_start, date_stop, AM = record
    id = Tid(id_wide)           # conversion to (possibly) narrower type
    push!(fp.id_counter, id)
    push!(fp.sink,
          (id, TAM_ix(fp.AMs[AM]), AMDB_Date(date_start)..AMDB_Date(date_stop)))
end

Base.close(fp::FirstPass) = close(fp.sink)

parser_id_am = Line(PositiveInteger(Int64),
                    DateYYYYMMDD(), DateYYYYMMDD(), Skip(), Skip(),
                    ViewBytes())

dir = data_path("first_pass")
mkpath(dir)
fp = FirstPass(parser_id_am, dir)
error_io = open(data_path("first_pass_errors.txt"), "w")
println(error_io, "first pass started at $(Dates.now()) on machine $(gethostname())")
for file in all_data_files()
    println("processing $file")
    err = process_file(file, parser_id_am, fp)
    show(error_io, err)
end
close(error_io)
close(fp)

# save the keys
save(meta_path(dir),
     "AM_keys", map(String, keys(fp.AMs)),
     "id_counter", fp.id_counter)

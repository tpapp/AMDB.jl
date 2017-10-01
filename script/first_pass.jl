using AMDB
using DataStructures
using JLD

import AMDB: SKIPFIELD, ByteVector, accumulate_file, data_file,
    all_data_files, data_path

# if this part breaks, then colnames changes, rewrite
cols = AMDB.data_colnames()
@assert cols[1] == "PENR"
@assert cols[6] == "AM"

accumulators = (counter(Int),                               # individual ID
                SKIPFIELD, SKIPFIELD, SKIPFIELD, SKIPFIELD, # skip 4 fields
                Set{ByteVector}()) # labor market status string
error_io = open(data_path("first_pass_errors.txt"), "w")
println(error_io, "first pass started at $(Dates.now())")
for file in all_data_files()
    println("processing $file")
    err = accumulate_file(file, accumulators)
    show(error_io, err)
end
close(error_io)

individuals = accumulators[1]

save(data_path("first_pass.jld"),
     "ids", collect(keys(individuals)),
     "counts", collect(values(individuals)),
     "AM_keys", sort(collect(accumulators[6]), lt=lexless))

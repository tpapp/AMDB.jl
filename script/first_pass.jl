# first pass: read whole file, save in binary format, count IDs for
# collation, store AM spell strings in the order of appearance

using AMDB:
    ColSpec, make_firstpass, data_path, firstpass_process_file, all_data_files,
    get_positions, AutoIndex
# using ArgCheck
using ByteParsers:
    Line, DateYYYYMMDD, PosInteger, ViewBytes, parsedtype, ByteVector, FixEmpty
# using DiscreteRanges
using DocStringExtensions: SIGNATURES
using JLD2
using FileIO
using LargeColumns: meta_path

# AMDB.preview_column("AVG_BMG")

colspecs = [
    # 1, person id
    ColSpec("PENR", PosInteger(Int32); index_type = Int32),
    # 2:3, spell start, Date
    ColSpec("STARTEND", AMDB.DatePair()),
    # 4, firm id, Int64 for some reason?
    ColSpec("BENR", FixEmpty(-1, PosInteger(Int64)); index_type = Int32), # missing as -1
    # 6, labor market status
    ColSpec("AM", ViewBytes(), index_type = Int8),
    # 17, number of employees,  seems to be capped at 1000?
    ColSpec("SUM_MA", FixEmpty(-1, PosInteger(Int16))), # missing as -1
    # 19, industry code, 4 digits, has strings like XXXX?
    ColSpec("NACE", ViewBytes(); index_type = Int16),
    # 21, geographical location; 3 digits
    ColSpec("RGS", ViewBytes(); index_type = UInt8), # enough to contain it, has around 130
    # 35, wage data
    ColSpec("AVG_BMG", FixEmpty(-1, PosInteger(Int32))), # missing wage as -1
]

dir = data_path("first_pass")
mkpath(dir)
fp = make_firstpass(dir, colspecs)

# quick check
@assert fp.colnames ==
    [:PENR, :STARTEND, :BENR, :AM, :SUM_MA, :NACE, :RGS, :AVG_BMG]

error_io = open(data_path("first_pass_errors.txt"), "w")
println(error_io,
        "first pass started at $(Dates.now()) on machine $(gethostname())")
for filename in all_data_files()
    println("processing $filename")
    err = firstpass_process_file(filename, fp)
    show(error_io, err)
end
close(error_io)
close(fp)

"""
    $SIGNATURES

Convert keys to string.
"""
collect_keys(accumulator::AutoIndex{<: Integer}) = collect(keys(accumulator))

function collect_keys(accumulator::AutoIndex{<:SubArray{UInt8}})
    map(String ∘ copy, keys(accumulator))
end

# save the keys
save(meta_path(dir, "meta.jld2"),
     "id_counter", fp.orderedcounter,
     AMDB.META_INDEXED_KEYS, map(collect_keys, fp.accumulators),
     AMDB.META_INDEXED_POSITIONS, collect(get_positions(fp.multisubs))[2:end],
     AMDB.META_COLUMN_NAMES, fp.colnames)

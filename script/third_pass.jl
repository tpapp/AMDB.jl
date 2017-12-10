######################################################################
# third pass: order collated dataset by start dates
######################################################################

using AMDB: data_path
using JLD2
using DocStringExtensions: SIGNATURES
using FileIO: load, save
using LargeColumns: meta_path, MmappedColumns
using ProgressMeter: @showprogress
import Base.Mmap: sync!

collated = MmappedColumns(data_path("collated"));

meta = load(meta_path(collated, "meta.jld2"))

const date_col_index = findfirst(meta[AMDB.META_COLUMN_NAMES], :STARTEND)

@assert date_col_index > 0

"""
    $SIGNATURES

Iterating through indices in `ix`, sort spells for each individual by the start
date in `date_col_index`.
"""
function order_date_start!(ix, collated)
    @showprogress for r in ix
        collated[r] .= sort(collated[r], by = x -> x[date_col_index].left)
    end
end

order_date_start!(meta[AMDB.META_IX], collated) # sort by dates
sync!(collated)                 # make sure it is synced to disk

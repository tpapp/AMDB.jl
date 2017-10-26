######################################################################
# third pass: order collated dataset by start dates
######################################################################

using AMDB
using DiscreteRanges
using JLD2
using FileIO
using RaggedData
using LargeColumns
using WallTimeProgress
import Base.Mmap: sync!

collated = MmappedColumns(data_path("collated"));

ix = load(meta_path(collated, "meta.jld2"))["ix"];

# wrap in a function for faster execution
function order_date_start(ix, collated)
    tracker = WallTimeTracker(10_000_000; item_name = "record")
    @inbounds for i in indices(ix, 1)
        jx = ix[i]
        collated[jx] .= sort(collated[jx], by = x -> x[2].left)
        increment!(tracker)
    end
end

order_date_start(ix, collated)  # sort by dates

sync!(collated)                 # make sure it is synced to disk

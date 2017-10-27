######################################################################
# second pass: collate dataset by individual IDs, forming contiguous records
######################################################################

using AMDB
using DiscreteRanges
using JLD2
using FileIO
using RaggedData
using LargeColumns
using WallTimeProgress
import Base.Mmap: sync!

first_pass = MmappedColumns(data_path("first_pass"));

N = length(first_pass)

collated = MmappedColumns(data_path("collated"), N,
                          Tuple{Int8, DiscreteRange{AMDB_Date}});

# load metadata
meta = load(meta_path(first_pass, "meta.jld2"))
id_counter = meta["id_counter"]

coll, ix, id = collate_index_keys(id_counter, true);

# collate by IDs

function collate_first_pass!(coll, first_pass, collated)
    tracker = WallTimeTracker(10_000_000; item_name = "record")
    @assert length(first_pass) == length(collated)
    @inbounds for i in indices(first_pass, 1)
        id, AM_ix, dates = first_pass[i]
        j = next_index!(coll, id)
        collated[j] = (AM_ix, dates)
        increment!(tracker)
    end
end

collate_first_pass!(coll, first_pass, collated)

sync!(collated)

# save metadata

save(meta_path(collated, "meta.jld2"),
     "ix", ix,
     "AM_keys", meta["AM_keys"])

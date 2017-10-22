using AMDB
import AMDB: mmapped_vector
using DiscreteRanges
using JLD
using RaggedData
using WallTimeProgress
import Base.Mmap: sync!

id_counter = deserialize_data("first_pass_id_counter.jls")
N = count(id_counter)           # total number of observations

coll, ix, id = collate_index_keys(id_counter, true)

# write out indexer (`ix`) and ids (`id`)
serialize_data("collated_id.jls", id)
serialize_data("collated_ix.jls", ix)

# first pass: read
fp_id = mmapped_vector("first_pass_id.bin", Int32, N, "r");
fp_AM_ix = mmapped_vector("first_pass_AM_ix.bin", Int8, N, "r");
fp_dates = mmapped_vector("first_pass_dates.bin",
                          DiscreteRange{AMDB_Date}, N, "r");

# second pass: write
coll_AM_ix = mmapped_vector("collated_AM_ix.bin", Int8, N, "w+");
coll_dates = mmapped_vector("collated_date_start.bin",
                            DiscreteRange{AMDB_Date}, N, "w+");

function collate_first_pass(coll, fp_id,
                            fp_AM_ix, fp_dates, coll_AM_ix, coll_dates,
                            N = length(fp_id))
    tracker = WallTimeTracker(10_000_000; item_name = "record")
    @inbounds for i in 1:N
        j = next_index!(coll, fp_id[i])
        coll_AM_ix[j] = fp_AM_ix[i]
        coll_dates[j] = fp_dates[i]
        increment!(tracker)
    end
end

collate_first_pass(coll, fp_id, fp_AM_ix, fp_dates, coll_AM_ix, coll_dates)

# order by dates

function order_date_start(ix, coll_AM_ix, coll_dates)
    tracker = WallTimeTracker(10_000_000; item_name = "record")
    @inbounds for i in indices(ix, 1)
        jx = ix[i]
        p = sortperm(coll_dates[jx], by = x->x.left)
        coll_AM_ix[jx] .= coll_AM_ix[jx][p]
        coll_dates[jx] .= coll_dates[jx][p]
        increment!(tracker)
    end
end

order_date_start(ix, coll_AM_ix, coll_dates)

sync!(coll_AM_ix)
sync!(coll_dates)

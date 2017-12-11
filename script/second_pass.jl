# second pass: collate dataset by individual IDs, forming contiguous records

using AMDB: data_path
using DocStringExtensions: SIGNATURES
import JLD2
using FileIO: save, load
using RaggedData: contiguous_invperm!, contiguous_ranges, ordered_counts
using LargeColumns: MmappedColumns, meta_path, get_columns
using ProgressMeter: @showprogress
using Base.Mmap: mmap, sync!

# load first pass
first_pass = MmappedColumns(data_path("first_pass"));
columns_first = get_columns(first_pass)
N = length(first_pass)

# load metadata
meta = load(meta_path(first_pass, "meta.jld2"))
counts = ordered_counts(columns_first[1], Int32)

# permute to make IDs contiguous
tmp = MmappedColumns(mktempdir(), N, Tuple{Int32}); # permutations are mmapped
ip = get_columns(tmp)[1];
contiguous_invperm!(ip, get_columns(first_pass)[1], counts)

collated = MmappedColumns(data_path("collated"), N, eltype(first_pass));

columns_collated = get_columns(collated)

"""
    $SIGNATURES

Apply inverse permutation `ip` from `source` to `dest`.
"""
function permute_column!(ip, source, dest)
    @assert eltype(source) == eltype(dest)
    println("permuting column of $(eltype(source))s...")
    @showprogress for i in indices(ip, 1)
        dest[ip[i]] = source[i]
    end
    sync!(dest)
end

for (source, dest) in zip(columns_first, columns_collated)
    permute_column!(ip, source, dest)
end

sync!(collated)

# indices are now contiguous, CHECK
ix = contiguous_ranges(counts);

# function check_contiguous(x, ix)
#     _same(x) = all(x[1] .== x[2:end])
#     for r in ix
#         xv = @view(x[r])
#         if !_same(xv)
#             println("non-contiguous at $r")
#             println(xv)
#         end
#     end
# end

# check_contiguous(get_columns(collated)[1], ix)

meta2 = copy(meta)
meta2[AMDB.META_IX] = ix

# save metadata, now it can be reused as is for the third pass and the data analysis
save(meta_path(collated, "meta.jld2"), meta2)

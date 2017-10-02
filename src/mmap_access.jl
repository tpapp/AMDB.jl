using JLD

"""
    cumsum2range(cumsums, i)

Let `c` be a vector of (integer) counts, and `cumsums` its cumulative sum.

For an index `i`, return a `UnitRange` that corresponds to integers between
`c₁+...+cᵢ+1` and `c₁+...+cᵢ₊₁`, inclusive.
"""
function cumsum2range(cumsums::Vector{T}, i) where {T <: Integer}
    UnitRange(i == 1 ? one(T) : cumsums[i-1]+one(T), cumsums[i])
end

"""
    CumSumWrapper(cumsums)

A wrapper for `cumsum2range`, returning ranges for each index — representing a
vector, calculating elements on demand.
"""
struct CumSumWrapper{T}
    cumsums::Vector{T}
end

Base.length(csw::CumSumWrapper) = length(csw.cumsums)

Base.getindex(csw::CumSumWrapper, i) = cumsum2range(csw.cumsums, i)

Base.eltype(csw::CumSumWrapper{T}) where T = UnitRange{T}

Base.size(csw::CumSumWrapper) = (length(csw), )

meta_records_file(base_filename) = data_path(base, "_meta.jld")

function mmapped_arrays(base_filename, N, mode = "r")
    filename_(part) = data_path(base_filename, "_", part)
    mmapped_(part, T) = Mmmap.mmap(open(filename_(part), mode), Array{T}, (N,))
    (mmapped_("id", Int32),
     mmapped_("cumsum", Int32),
     mmapped_("spell_start", Date),
     mmapped_("spell_stop", Date),
     mmapped_("spell_raw_type", Date))
end

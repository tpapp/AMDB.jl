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

function first_pass_filenames(base_filename)
    fn(part) = data_path("$(base_filename)_$(part).bin")
    fn("id"), fn("AM_ix"), fn("date_start"), fn("date_stop")
end

function first_pass_streams(base_filename, mode)
    map(fn -> open(fn, mode), first_pass_filenames(base_filename))
end

function first_pass_mmap(base_filename, N, mode = "r+")
    id, AM_ix, date_start, date_stop = first_pass_streams(base_filename, mode)
    mmapped_(stream, T) = Mmap.mmap(stream, Vector{T}, (N,))
    (mmapped_(id, Int32), mmapped_(AM_ix, Int8),
     mmapped_(date_start, Date), mmapped_(date_stop, Date))
end

function mmapped_arrays(base_filename, N, mode = "r")
    filename_(part) = data_path(base_filename, "_", part)
    mmapped_(part, T) = Mmmap.mmap(open(filename_(part), mode), Array{T}, (N,))
    (mmapped_("id", Int32),
     mmapped_("cumsum", Int32),
     mmapped_("spell_start", Date),
     mmapped_("spell_stop", Date),
     mmapped_("spell_raw_type", Date))
end


"""
    cumsum2counter(cumsums)

Return an initialized counter from cumulative sums. When adding an element, it
should be incremented, _then_ the incremented value returned.
"""
function cumsum2counter(cumsums::Vector{T}) where T
    counters = similar(cumsums)
    counters[1] = 0
    counters[2:end] .= cumsums[1:(end-1)]
    counters
end

module AMDB

using ArgCheck: @argcheck
using ByteParsers: parsenext, isparsed
using DocStringExtensions: SIGNATURES
using EnglishText
using FlexDates: FlexDate
# FIXME commented out selective import until
# https://github.com/mauro3/Parameters.jl/issues/43 is fidex
using Parameters #: @unpack
using WallTimeProgress: WallTimeTracker, increment!

export
    data_file, data_path, all_data_files, data_colnames,
    serialize_data, deserialize_data,
    AMDB_Date

using CodecZlib




# paths

"""
    $(SIGNATURES)

Return the directoy for the AMDB data dump.

The user should set the environment variable `AMDB_FILES`.
"""
function data_directory()
    key = "AMDB_FILES"
    @assert(haskey(ENV, key),
            "You should put the path to the raw files in ENV[$key].")
    normpath(expanduser(ENV[key]))
end

"""
    $(SIGNATURES)

Add `components` (directories, and potentially a filename) to the AMDB
data dump directory.
"""
data_path(components...) = joinpath(data_directory(), components...)

const VALID_YEARS = 2000:2016

"""
    $(SIGNATURES)

The path for the AMDB data dump file (gzip-compressed CSV) for a given
year. Example:

```julia
AMDB.data_file(2000)
```
"""
function data_file(year)
    @assert year ∈ VALID_YEARS "Year outside $(VALID_YEARS)."
    ## special-case two years combined
    yearnum = year ≤ 2014 ? @sprintf("%02d", year-2000) : "1516"
    data_path("mon_ew_xt_uni_bus_$(yearnum).csv.gz")
end

"""
    $(SIGNATURES)

"""
all_data_files() = unique(data_file.(VALID_YEARS))

"""
    $(SIGNATURES)

Return the AMDB column names for the data dump as a vector.
"""
function data_colnames()
    header = readlines(data_path("mon_ew_xt_uni_bus.cols.txt"))[1]
    split(header, ';')
end

"""
    $(SIGNATURES)

Serialize data into `filename` within the data directory. A new file is created,
existing files are overwritten.
"""
function serialize_data(filename, value)
    open(io -> serialize(io, value), data_path(filename), "w")
end

"""
    $(SIGNATURES)

Deserialize data from `filename` within the data directory.
"""
function deserialize_data(filename)
    open(deserialize, data_path(filename), "r")
end


# error logging

struct FileError
    line_number::Int
    line_content::Vector{UInt8}
    line_position::Int
end

function Base.show(io::IO, file_error::FileError)
    @unpack line_number, line_content, line_position = file_error
    println(io, chomp(String(line_content)))
    print(io, " "^(line_position - 1))
    println(io, "^ line $(line_number), byte $(line_position)")
end

struct FileErrors{S}
    filename::S
    errors::Vector{FileError}
end

FileErrors(filename::String) = FileErrors(filename, Vector{FileError}(0))

function log_error(file_errors::FileErrors, line_number, line_content,
                   line_position)
    push!(file_errors.errors,
          FileError(line_number, line_content, line_position))
end

function Base.show(io::IO, file_errors::FileErrors)
    @unpack filename, errors = file_errors
    error_quantity = ItemQuantity(length(errors), "error")
    println(io, "$filename: $(error_quantity)")
    for e in errors
        show(io, e)
    end
end

Base.count(file_errors::FileErrors) = length(file_errors.errors)




struct AutoIndex{T,S}
    dict::Dict{T,S}
end

AutoIndex{T,S}() where {T,S} = AutoIndex(Dict{T,S}())

Base.length(ai::AutoIndex) = length(ai.dict)

function Base.getindex(ai::AutoIndex{T,S}, elt::E) where {T,S,E}
    @unpack dict = ai
    ix = get(dict, elt, zero(S))
    if ix == zero(S)
        v = length(dict)
        @assert v < typemax(S) "Number of elements reached typemax($S)"
        v += one(S)
        dict[T==E ? elt : convert(T, elt)] = v
        v
    else
        ix
    end
end

function Base.keys(ai::AutoIndex)
    kv = collect(ai.dict)
    sort!(kv; by = last)
    first.(kv)
end


# dates

const EPOCH = Date(2000,1,1)    # all dates relative to this

const AMDB_Date = FlexDate{EPOCH,Int16} # should be enough for everything



"""

"""
function process_stream(io::IO, parser, f, errors::FileErrors;
                        tracker_period = 10_000_000, max_lines = -1)
    tracker = WallTimeTracker(tracker_period; item_name = "line")
    while !eof(io) && (max_lines < 0 || count(tracker) < max_lines)
        line_content = readuntil(io, 0x0a)
        record = parsenext(parser, line_content, 1, UInt8(';'))
        if isparsed(record)
            f(unsafe_get(record))
        else
            log_error(errors, count(tracker), line_content, getpos(record))
        end
        increment!(tracker)
    end
end

function process_file(filename, parser, f; args...)
    io = GzipDecompressorStream(open(filename))
    errors = FileErrors(filename)
    process_stream(io, parser, f, errors; args...)
    errors
end


# narrowest ninteger

"""
    narrowest_Int(min, max, [signed = true])

Return the narrowest subtype of `Signed` or `Unsigned` (depending on Signed)
that can contain values between `min` and `max`.
"""
function narrowest_Int(min_::Integer, max_::Integer, signed = true)
    @argcheck min_ ≤ max_
    Ts = signed ?
        [Int8, Int16, Int32, Int64, Int128] :
        [UInt8, UInt16, UInt32, UInt64, UInt128]
    narrowest_min_ = findfirst(T -> typemin(T) ≤ min_, Ts)
    narrowest_max_ = findfirst(T -> max_ ≤ typemax(T), Ts)
    @assert((narrowest_min_ * narrowest_max_) > 0,
            "Can't accomodate $min_:$max_ within given types.")
    Ts[max(narrowest_min_, narrowest_max_)]
end

"""
    to_narrowest_Int(xs, [signed = true])

Convert `xs` to the narrowest integer type that will contain it (a subtype of
`Signed` or `Unsigned`, depending on `signed`).
"""
function to_narrowest_Int(xs::AbstractVector{<: Integer}, signed = true)
    T = narrowest_Int(extrema(xs)..., signed)
    T.(xs)
end

end # module

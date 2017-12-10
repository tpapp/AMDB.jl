__precompile__()
module AMDB

import Base: close, count, keys, length, show, keys, values

using ArgCheck: @argcheck
using ByteParsers:
    isparsed, Skip, Line, ByteVector, @checkpos, AbstractParser, parsedtype,
    DateYYYYMMDD, MaybeParsed, getpos
import ByteParsers: parsenext
using CodecZlib: GzipDecompressorStream
using DataStructures: OrderedDict
using DocStringExtensions: SIGNATURES
using DiscreteRanges: DiscreteRange
using EnglishText: ItemQuantity
using FlexDates: FlexDate
using LargeColumns: SinkColumns, meta_path
using Lazy: @forward
using Parameters: @unpack
using WallTimeProgress: WallTimeTracker, increment!

export
    data_file, data_path, all_data_files, data_colnames,
    serialize_data, deserialize_data,
    AMDB_Date


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

function show(io::IO, file_error::FileError)
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

function show(io::IO, file_errors::FileErrors)
    @unpack filename, errors = file_errors
    error_quantity = ItemQuantity(length(errors), "error")
    println(io, "$filename: $(error_quantity)")
    for e in errors
        show(io, e)
    end
end

count(file_errors::FileErrors) = length(file_errors.errors)


# automatic indexation

struct AutoIndex{T, S <: Integer}
    dict::Dict{T, S}
end

show(io::IO, ai::AutoIndex{T, S}) where {T, S} =
    print(io, "automatically index $T => $S, $(length(ai.dict)) elements")

"""
    $SIGNATURES

Create an `AutoIndex` of object which supports automatic indexation of keys with
type `T` to integers (`<: S`). The mapping is implemented by making the object
callable.

`keys` retrieves all the keys in the order of appearance.
"""
AutoIndex(T, S) = AutoIndex(Dict{T,S}())

length(ai::AutoIndex) = length(ai.dict)

function (ai::AutoIndex{T,S})(elt::E) where {T,S,E}
    @unpack dict = ai
    ix = get(dict, elt, zero(S))
    if ix == zero(S)
        v = length(dict)
        @assert v < typemax(S) "Number of elements reached typemax($S), can't insert $elt"
        v += one(S)
        dict[T==E ? elt : convert(T, elt)] = v
        v
    else
        ix
    end
end

function keys(ai::AutoIndex)
    kv = collect(ai.dict)
    sort!(kv; by = last)
    first.(kv)
end

# FIXME remove unused 
# # map using a tuple of functions

# """
#     TupleMap(functions::Tuple)

# Return a callable that maps a tuple of the same dimension using `functions`,
# which should be a tuple of callables (do not need to be `<: Function`).

# ```julia
# struct AddOne end
# (::AddOne)(x) = x + one(x)
# f = TupleMap((AddOne(), identity))
# f((1,3))                        # (2,3)
# ```
# """
# struct TupleMap{T <: Tuple}
#     functions::T
# end

# (f::TupleMap)(x::Tuple) = map((g, z) -> g(z), f.functions, x)


# dates

"""
Epoch for consistent date compression in the database.
"""
const EPOCH = Date(2000,1,1)    # all dates relative to this

"""
Datatype used for compressed dates.
"""
const AMDB_Date = FlexDate{EPOCH,Int16} # should be enough for everything


# tuple processing (first pass)

# FIXME remove, unused
# """
#     $SIGNATURES

# Join the second and the third argument as a DiscreteRange compressed dates.
# """
# join_dates(record) = _join_dates(record...)

# @inline _join_dates(id, spell_start, spell_end, rest...) =
#     id, DiscreteRange(AMDB_Date(spell_start), AMDB_Date(spell_end)), rest...

struct MultiSubs{P, F}
    functions::F
end

"""
    $SIGNATURES

Return a callable that maps tuples by maps elements at `positions` with the
corresponding function in `functions`, leaving the rest of the elements alone.
"""
function MultiSubs(positions::NTuple{N, Int}, functions::F) where {N, F}
    @argcheck length(positions) == length(functions)
    @argcheck allunique(positions) && all(positions .> 0)
    MultiSubs{positions, F}(functions)
end

"""
    $SIGNATURES

Return positions of substituted indices.
"""
get_positions(::MultiSubs{P}) where P = P

@generated function (m::MultiSubs{P})(x::NTuple{N, Any}) where {P, N}
    result = Any[:(x[$i]) for i in 1:N]
    for (i, p) in enumerate(P)
        result[p] = :((m.functions[$i])(x[$p]))
    end
    :(tuple($(result...)))
end



"""
    OrderedCounter{T,S}()

A wrapper for OrderedDict that is callable, counts and returns its argument.
"""
struct OrderedCounter{T,S <: Integer}
    dict::OrderedDict{T,S}
end

OrderedCounter{T, S}() where {T, S} = OrderedCounter(OrderedDict{T, S}())

function (oc::OrderedCounter{T,S})(x::T) where {T,S}
    oc.dict[x] = get(oc.dict, x, zero(S)) + one(S)
    x
end

@forward OrderedCounter.dict keys, values

"""
    $SIGNATURES

Return the counts as an OrderedDict.
"""
get_counts(oc::OrderedCounter) = oc.dict

# first pass processing

"""
    $SIGNATURES

Merge the two column names for start and end dates of spells.
"""
function merged_colnames(; colnames = data_colnames())
    @argcheck colnames[2:3] == ["ANFDAT", "ENDDAT"]
    vcat(colnames[1:1], ["STARTEND"], colnames[4:end])
end

"""
    DatePair()

Parse two consecutive dates.
"""
struct DatePair <: AbstractParser{DiscreteRange{AMDB_Date}} end

function parsenext(::DatePair, str::ByteVector, pos, sep)
    D = DateYYYYMMDD()
    @checkpos (pos, date1) = parsenext(D, str, pos, sep)
    @checkpos (pos, date2) = parsenext(D, str, pos, sep)
    return MaybeParsed(pos, DiscreteRange(AMDB_Date(date1), AMDB_Date(date2)))
    @label error
    MaybeParsed{Date}(pos_to_error(pos))
end

struct ColSpec
    name::AbstractString
    parser::AbstractParser
    index_type::Type{ <: Union{Void, Integer}}
end

"""
    $SIGNATURES

Create a column specification for first pass reading.

`name` is the name of the column, parsed using `parser`.

When `index_type::Type{<:Integer}` is given, it is used as a result type to
generate a `AutoIndex` with the given result type, except for the first parsed
column, which uses an `OrderedCounter`.

See [`make_first_pass`](@ref).
"""
ColSpec(name, parser; index_type = Void) = ColSpec(name, parser, index_type)

"""
First pass processing.

`lineparser` parsed each line.

When successful, it is transformed with `multisubs`, changing the state of
`accumulators`.

The result is written into `sink`.
"""
struct FirstPass{L <: Line, C, A <: Tuple,
                 M <: MultiSubs, S <: SinkColumns}
    lineparser::L
    orderedcounter::C
    accumulators::A
    multisubs::M
    sink::S
    colnames::Vector{Symbol}
end

function show(io::IO, fp::FirstPass)
    @unpack lineparser, accumulators, colnames = fp
    println(io, "First pass parsing")
    println(io, "Line parser:")
    println(io, lineparser)
    println(io, "Accumulators:")
    println(io, accumulators)
    println(io, "Colnames:")
    println(io, colnames)
end

function make_firstpass(dir, colspecs::AbstractVector{ColSpec};
                        colnames = merged_colnames(),
                        skip_parser = Skip())
    @argcheck allunique(colnames) "Column names are not unique."
    matched_specs = map(colspecs) do colspec
        @unpack name, parser, index_type = colspec
        colindex = findfirst(colnames, name)
        colindex > 0 || throw(ArgumentError("column $(colname) not found"))
        (colindex, name, parser, index_type)
    end
    # make sure column indexes are strictly increasing (no repetition, right order)
    issorted(matched_specs, lt = <, by = first) ||
        throw(ArgumentError("column names need to be in the same order as in data"))
    # the default is to skip
    parsers = fill!(Vector(matched_specs[end][1]), skip_parser)
    result_types = Any[]
    sub_positions = Int[]
    sub_functions = Any[]
    names = Vector{Symbol}()
    for (position, (colindex, name, parser, index_type)) in enumerate(matched_specs)
        parsers[colindex] = parser
        result_type = parsedtype(parser)
        if !(index_type ≡ Void)
            @argcheck index_type <: Integer
            if colindex == 1
                filter = OrderedCounter{result_type, index_type}()
            else
                filter = AutoIndex(result_type, index_type)
            end
            result_type = index_type
            push!(sub_positions, position)
            push!(sub_functions, filter)
        end
        push!(result_types, result_type)
        push!(names, Symbol(name))
    end
    FirstPass(Line(parsers...),
              sub_functions[1],
              tuple(sub_functions[2:end]...),
              MultiSubs(tuple(sub_positions...), tuple(sub_functions...)),
              SinkColumns(dir, Tuple{result_types...}),
              names)
end

close(fp::FirstPass) = close(fp.sink)

"""
    $SIGNATURES

Process the stream `io` by line. Each line is parsed using `parser`, then

1. if the parsing is successful, `f!` is called on the parsed record,

2. if the parsing is not successful, an error is logged to `errors`. See
[`log_error`](@ref).

`tracker` is used to track progress.

When `max_lines > 1`, it is used to limit the number of lines parsed.
"""
function firstpass_process_stream(io::IO, fp::FirstPass, errors::FileErrors;
                                  tracker = WallTimeTracker(10_000_000;
                                                            item_name = "line"),
                                  max_lines = -1)
    @unpack lineparser, multisubs, sink = fp
    while !eof(io) && (max_lines < 0 || count(tracker) < max_lines)
        line_content = readuntil(io, 0x0a)
        record = parsenext(lineparser, line_content, 1, UInt8(';'))
        if isparsed(record)
            push!(sink, multisubs(unsafe_get(record)))
        else
            log_error(errors, count(tracker), line_content, getpos(record))
        end
        increment!(tracker)
    end
end

"""
    $SIGNATURES

Open `filename` and process the resulting stream with
[`firstpass_stream`](@ref), which the other arguments are passed on to. Return
the error log object.
"""
function firstpass_process_file(filename, fp; args...)
    io = GzipDecompressorStream(open(filename))
    errors = FileErrors(filename)
    firstpass_process_stream(io, fp, errors; args...)
    errors
end


# narrowest integer

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


# column selection

"""
    $SIGNATURES

Find the column matching a given column name, and return a tuple of parsers
constructed using `colnames_and_parsers`, which should be a vector of
parsers. The order of parsers is preserved, and should be
increasing. `skip_parser` is used to skip fields.

Example:

```julia
julia> column_parsers(["a", "b", "c", "d", "e"],
                      ["b" => DateYYYYMMDD(), "d" => PositiveInteger()])

(Skip(), DateYYYYMMDD(), Skip(), PositiveInteger())
```
"""
function column_parsers(colnames::AbstractVector,
                        colnames_and_parsers::AbstractVector{<: Pair},
                        skip_parser = Skip())
    @argcheck allunique(colnames) "Column names are not unique."
    indexes_and_parsers = map(colnames_and_parsers) do colname_and_parser
        colname, parser = colname_and_parser
        index = findfirst(colnames, colname)
        index > 0 || throw(ArgumentError("column $(colname) not found"))
        index => parser
    end
    # make sure column indexes are strictly increasing (no repetition, right order)
    issorted(indexes_and_parsers, lt = <, by = first) ||
        throw(ArgumentError("column names are not in the right order"))
    # the default is to skip
    parsers = fill!(Vector(first(indexes_and_parsers[end])), skip_parser)
    for (index, parser) in indexes_and_parsers
        parsers[index] = parser
    end
    tuple(parsers...)
end

"""
    $SIGNATURES

Return a sample of `N` values from column `colname` as a vector.

Optional arguments specity the file, how many lines to skip in between, etc. The
purpose of this function is to get a quick sense of what the values look like.
"""
function preview_column(colname;
                        N = 20,
                        skiplines = 10000,
                        year = 2000,
                        filename = AMDB.data_file(year),
                        colnames = AMDB.data_colnames(),
                        separator = ';')
    ix = findfirst(colnames, colname)
    ix > 0 || throw(error("column $colname not found"))
    info("$colname is in column $ix")
    io_gz = open(filename, "r")
    io = GzipDecompressorStream(io_gz)
    values = map(1:N) do _
        for _ in 1:skiplines
            readline(io)
        end
        line = readline(io)
        split(line, separator)[ix]
    end
    close(io)
    close(io_gz)
    values
end


# rudimentary format for metadata

"""
Key for the index of individual-specific spells, in metadata for collated
columns (`Vector{UnitRange{ <: Integer}}`).
"""
const META_IX = "ix"

"""
Key for the keys of indexed columns (ie strings), in metadata for collated
columns (`Vector{Vector{String}}`).
"""
const META_INDEXED_KEYS = "indexed_keys"

"""
Key for the keys of indexed columns (ie strings), in metadata for collated
columns (`Vector{Int}`).
"""
const META_INDEXED_POSITIONS = "indexed_positions"

"""
Key for the keys of indexed columns (ie strings), in metadata for collated
columns `(Vector{Symbol}`).
"""
const META_COLUMN_NAMES = "column_names"

"""
    $SIGNATURES

Read the collated dataset as a dictinary of `:colname => column` pairs.

All columns are of the same length, except for `:ix`, which contains ranges that
select contiguous records for an individual.
"""
function collated_dataset(dir = "collated")
    collated = MmappedColumns(data_path(dir))
    meta = load(meta_path(collated, "meta.jld2"))
    dict = Dict{Symbol, AbstractVector{<: Any}}()
    dict[:ix] = meta[META_IX]
    columns = collect(get_columns(collated))
    for (indexed_position, indexed_keys) in zip(meta[META_INDEXED_POSITIONS],
                                                meta[META_INDEXED_KEYS])
        columns[indexed_position] = IndirectArray(columns[indexed_position],
                                                  indexed_keys)
    end
    for (colname, column) in zip(meta[META_COLUMN_NAMES], columns)
        dict[colname] = column
    end
    dict
end

end # module

# first pass: read whole file, save in binary format, count IDs for
# collation, store AM spell strings in the order of appearance

using AMDB: data_path, all_data_files, data_file
using ByteParsers:
    Line, DateYYYYMMDD, PosInteger, ViewBytes, parsedtype, ByteVector, parsenext,
    isparsed, Skip
using DocStringExtensions: SIGNATURES
using CodecZlib: GzipDecompressorStream
using WallTimeProgress: WallTimeTracker, increment!

"""
A parser for just the columns we need for labor market transitions.
"""
const lineparser = Line(PosInteger(Int64), # PENR
                        Skip(),            # start, skip
                        Skip(),            # end, skip
                        Skip(),            # firm, skip
                        DateYYYYMMDD(),    # STICHTAG
                        ViewBytes())       # AM

"""
   $SIGNATURES

Read stream from `io` line by line, extract

1. person id,

2. sample date,

3. labor market status

then reclassify the last one with `aggregator`, then return the assembled
histories as a dictionary of person id to 12-element vectors.

The latter contain the histories of individuals. The value `missing` is used
when no observation is found in the sample.
"""
function read_aggregated_AMs(io::IO, aggregator::Associative{ByteVector, T}, missing::T,
                             lineparser = lineparser,
                             tracker = WallTimeTracker(10_000_000;
                                                       item_name = "line")) where T
    individuals = Dict{Int32, Vector{T}}()
    while !eof(io)
        line_content = readuntil(io, 0x0a)
        record = parsenext(lineparser, line_content, 1, UInt8(';'))
        if isparsed(record)
            (penr, stich, am) = unsafe_get(record)
            mon = Dates.month(stich) # just the month
            state = aggregator[am]   # look up from dictionary
            if !haskey(individuals, penr)
                record = individuals[penr] = fill(missing, 12)
            else
                record = individuals[penr]
            end
            record[mon] = state
            increment!(tracker) # display progress
        end
    end
    individuals
end

function read_aggregated_AMs(filename::String, args...)
    io_gz = open(filename, "r")
    io = GzipDecompressorStream(io_gz)
    individuals = read_aggregated_AMs(io, args...)
    close(io)
    close(io_gz)
    individuals
end

"""
    $SIGNATURES

Expand the shell mapping from a compact format of a dictionary of

```julia
classification => [keys...]
```

to a dictionary of

```julia
key => classification
```
"""
function expand_spell_mapping(spell_mapping::Dict{T, Vector{String}}) where T
    aggregator = Dict{ByteVector, T}()
    for (k, vs) in spell_mapping
        for v in vs
            aggregator[convert(ByteVector, v)] = k
        end
    end
    aggregator
end


# runtime code here

spell_mapping = Dict(# unemployed
                     Int8(1) => String["D2", "SR", "VM", "AS", "LS", "SC", "AL",
                                       "AO","66"],
                     # NA
                     Int8(0) => String["KD", "SV", "TO",
                                       # FIXME PLEASE PUT THESE SOMETHERE
                                       "AO", "AL", "SC", "VM", "66", "LS"],
                     # employed
                     Int8(2) => String["FBENG", "FBUN1", "FBKOM", "LE", "FBEB2",
                                       "FBBS1", "FBEB1", "FBSOL", "LFIBA", "FBKUA",
                                       "LFNRM", "FBEPU", "LFP30", "FBSOB", "SO",
                                       "FBES", "LW", "LFUBA", "SBSVA", "FBBS3",
                                       "FBUN3", "LFVOL", "FBUN2", "S1S2", "G1", "FU",
                                       "FBBP", "FBEB", "FBARB", "BE", "AA", "LFLST",
                                       "LFTEL", "LFVRL", "FD", "LFJAS", "FBGEB",
                                       "FBBEB", "FBES1", "FBBS2", "FBGBP"],
                     # other (inactive)
                     Int8(1) => String["SF", "KG", "AU", "W1", "TA", "MS", "BA",
                                       "ED", "LL", "AG", "AF", "EO", "KO", "RE",
                                       "MK", "PZ", "AM", "LF", "MP", "SG", "W2"])

aggregator = expand_spell_mapping(spell_mapping)
test_file = data_file(2000)
histories = read_aggregated_AMs(test_file, aggregator, Int8(-1))

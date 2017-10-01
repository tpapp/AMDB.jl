using CodecZlib
using WallTimeProgress
using EnglishText
using Parameters

######################################################################
# parsing primitives
######################################################################

# separator between fields
const SEP = UInt8(';')

"Invalid character."
const INVALID = -1

"End of line."
const EOL = -2

"Empty field."
const EMPTY = -3

"""
    validpos(pos)

Test if the returned position is valid. When not, this is an error and should be
propagated.
"""
validpos(pos) = pos > 0

const ByteVector = Vector{UInt8}

"""
    d, pos = tryparse_base10_tosep(str, start, [len])

Parse digits from `str` as an integer, until encountering `sep` or EOL.

Return the parsed integer and the position of the separator (or an error code,
see `validpos`).
"""
function parse_base10_tosep(str::ByteVector, start, len = length(str))
    n = 0
    z = UInt8('0')
    pos = start
    @inbounds while pos ≤ len
        chr = str[pos]
        chr == SEP && return n, pos == start ? EMPTY : pos
        maybe_digit = chr - z
        if 0 ≤ maybe_digit ≤ 9
            n = n*10 + maybe_digit
            pos += 1
        else
            return n, INVALID
        end
    end
    n, EOL
end

"""
    d, pos = parse_base10_fixed(str, start, stop)

Parse digits from `str` between positions `start` and `stop` (inclusive) as an
integer. `pos` is the position after parsing, it is either `stop + 1` or an
error code.
"""
function parse_base10_fixed(str::ByteVector, start, stop)
    n = 0
    z = UInt8('0')
    pos = start
    @inbounds while pos ≤ stop
        maybe_digit = str[pos] - z
        if 0 ≤ maybe_digit ≤ 9
            n = n*10 + maybe_digit
            pos += 1
        else
            return n, INVALID
        end
    end
    n, pos
end

"""
    d, pos = parse_date(str, start, strict = true)

Parse dates of the form "yyyymmdd".

When `strict = false`, zero days are replaced by 1 (a peculiarity of the dataset).
"""
function parse_date(str::ByteVector, start, strict = true)
    stop = start+8
    length(str) ≥ stop || return Date(0), EOL

    y, pos = parse_base10_fixed(str, start, start+3)
    validpos(pos) || return Date(0), pos

    m, pos = parse_base10_fixed(str, pos, pos+1)
    validpos(pos) || return Date(0), pos

    d, pos = parse_base10_fixed(str, pos, pos+1)
    validpos(pos) || return Date(0), pos

    str[pos] == SEP || @goto invalid

    d == 0 && (strict ? @goto(invalid) : (d = 1))

    (m ≤ 12 && d ≤ Base.Dates.daysinmonth(y, m)) || @goto invalid

    return Date(y, m, d), pos

    @label invalid
    Date(0), INVALID
end

function parse_skip(str::ByteVector, start, len = length(str))
    pos = start
    @inbounds while pos ≤ len
        str[pos] == SEP && return pos
        pos += 1
    end
    EOL
end

function parse_gobble(str::ByteVector, start, len = length(str))
    pos = parse_skip(str, start, len)
    @view(str[start:(pos-1)]), pos
end


######################################################################
# accumulators
######################################################################

"""
    sep_pos = accumulate_field(str, pos, accumulator)

Parse the field starting at `str[pos]` and process by `accumulator` as specified
by the latter. Return the position of the separator (also used for error
messages).
"""
function accumulate_field end

struct SkipField end

const SKIPFIELD = SkipField()

accumulate_field(str, pos, ::SkipField) = parse_skip(str, pos)

function accumulate_field(str, pos, acc::Set{Int})
    value, pos = parse_base10_tosep(str, pos)
    # NOTE checking that `value ∉ acc` before push! is much better for performance
    validpos(pos) && value ∉ acc && push!(acc, value)
    pos
end

function accumulate_field(str, pos, acc::Set{ByteVector})
    value, pos = parse_gobble(str, pos)
    validpos(pos) && value ∉ acc && push!(acc, value)
    pos
end

function accumulate_field(str, pos, acc::Set{Date})
    value, pos = parse_date(str, pos)
    validpos(pos) && value ∉ acc && push!(acc, value)
    pos
end

accumulate_line_(str, pos::Int, fieldindex::Int) = (0, 0)

function accumulate_line_(str, pos, fieldindex, accumulator, accumulators...)
    next_pos = accumulate_field(str, pos, accumulator)
    if validpos(next_pos)
        accumulate_line_(str, next_pos + 1, fieldindex + 1, accumulators...)
    else
        pos, fieldindex
    end
end

accumulate_line(str, accumulators) = accumulate_line_(str, 1, 1, accumulators...)

######################################################################
# error logging
######################################################################

struct FileError
    line_number::Int
    line_content::ByteVector
    line_position::Int
    field_index::Int
end

function Base.show(io::IO, file_error::FileError)
    @unpack line_number, line_content, line_position, field_index = file_error
    println(io, String(line_content))
    print(io, " "^(line_position - 1))
    println(io, "^ line $(line_number), field $(field_index), byte $(line_position)")
end

struct FileErrors{S}
    filename::S
    errors::Vector{FileError}
end

FileErrors(filename::String) = FileErrors(filename, Vector{FileError}(0))

function log_error(file_errors::FileErrors, line_number, line_content,
                   line_position, field_index)
    push!(file_errors.errors,
          FileError(line_number, line_content, line_position, field_index))
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

######################################################################
# read whole file
######################################################################

function accumulate_stream(io::IO, errors::FileErrors, accumulators;
                           tracker_period = 10_000_000, max_lines = -1)
    tracker = WallTimeTracker(tracker_period; item_name = "line")
    while !eof(io) && (max_lines < 0 || count(tracker) < max_lines)
        line_content = readuntil(io, 0x0a)
        pos, ix = accumulate_line(line_content, accumulators)
        pos == 0 || log_error(errors, count(tracker), line_content, pos, ix)
        increment!(tracker)
    end
end

function accumulate_file(filename, accumulators; args...)
    io = GzipDecompressionStream(open(filename))
    errors = FileErrors(filename)
    accumulate_stream(io, errors, accumulators; args...)
    errors
end

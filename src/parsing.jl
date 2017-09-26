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

"""
    d, pos = tryparse_base10_tosep(str, start, [len])

Parse digits from `str` as an integer, until encountering `sep` or EOL.

Return the parsed integer and the position of the separator (or an error code,
see `validpos`).
"""
function parse_base10_tosep(str::Vector{UInt8}, start, len = length(str))
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
function parse_base10_fixed(str::Vector{UInt8}, start, stop)
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
    d, pos = parse_date(str, start)

Parse dates of the form "yyyymmdd". When the month or the day is zero, they are
replaced by 1 (a peculiarity of the dataset).
"""
function parse_date(str::Vector{UInt8}, start)
    stop = start+8
    length(str) ≥ stop || return Date(0), EOL

    y, pos = parse_base10_fixed(str, start, start+3)
    validpos(pos) || return Date(0), pos

    m, pos = parse_base10_fixed(str, pos, pos+1)
    validpos(pos) || return Date(0), pos

    d, pos = parse_base10_fixed(str, pos, pos+1)
    validpos(pos) || return Date(0), pos

    str[pos] == SEP || return Date(0), INVALID

    m = max(m, 1)
    d = max(d, 1)
    (m ≤ 12 && d ≤ Base.Dates.daysinmonth(y, m)) || return Date(0), INVALID

    Date(y, m, d), pos
end

function parse_skip(str::Vector{UInt8}, start, len = length(str))
    pos = start
    @inbounds while pos ≤ len
        str[pos] == SEP && return pos
        pos += 1
    end
    EOL
end

function parse_gobble(str::Vector{UInt8}, start, len = length(str))
    pos = parse_skip(str, start, len)
    @view(str[start:(pos-1)]), pos
end

"""
    accumulate_field(
"""
function accumulate_field end

struct SkipField end

accumulate_field(::SkipField, str, start) = parse_skip(str, start)

struct AccumulateField{T}
    values::Set{T}
end

AccumulateField(T) = AccumulateField(Set{T}())

Base.values(acc::AccumulateField) = acc.values

function accumulate_field(acc::AccumulateField{Int}, str, start)
    value, pos = parse_base10_tosep(str, start)
    validpos(pos) && push!(acc.values, value)
    pos
end

function accumulate_field(acc::AccumulateField{Vector{UInt8}}, str, start)
    value, pos = parse_gobble(str, start)
    validpos(pos) && push!(acc.values, value)
    pos
end

function accumulate_field(acc::AccumulateField{Date}, str, pos)
    value, pos = parse_date(str, pos)
    validpos(pos) && push!(acc.values, value)
    pos
end

accumulate_line_(str, pos) = nothing

accumulate_line_(str, pos, fieldparser) = accumulate_field(fieldparser, str, pos)

function accumulate_line_(str, pos, fieldparser, fieldparsers...)
    status, pos = accumulate_field(fieldparser, str, pos)
    if validpos(pos)
        accumulate_line_(str, pos, fieldparsers...)
    else
        # report error
    end
end


accumulate_line(str, fieldparsers) = accumulate_line_(str, 1, fieldparsers...)

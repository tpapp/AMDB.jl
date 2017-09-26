# separator between fields
const SEP = UInt8(';')

struct Invalid end

const INVALID = Invalid()

"""
    Nullable(d), pos = tryparse_base10_tosep(str, start, [stop])

Parse digits from `str` as an integer, until encountering `sep` or the position
`stop`.

Return the parsed integer as a `Nullable`, and the position of the *next*
unparsed character.

When encountering a character that is not a digit or `SEP`, return a null value.
"""
function tryparse_base10_tosep(str::Vector{UInt8}, start, stop = length(str))
    n = 0
    z = UInt8('0')
    pos = start
    @inbounds while pos ≤ stop
        chr = str[pos]
        chr == SEP && return Nullable(n, pos ≠ start), pos
        maybe_digit = chr - z
        if 0 ≤ maybe_digit ≤ 9
            n = n*10 + maybe_digit
            pos += 1
        else
            return Nullable(n, false), pos
        end
    end
    Nullable(n), pos
end

"""
    Nullable(d) = tryparse_base10_fixed(str, start, [stop])

Parse digits from `str` between positions `start` and `stop` (inclusive) as an
integer.

Return null when anything other than digits are encountered.
"""
function tryparse_base10_fixed(str::Vector{UInt8}, start, stop)
    n = 0
    z = UInt8('0')
    pos = start
    @inbounds while pos ≤ stop
        maybe_digit = str[pos] - z
        if 0 ≤ maybe_digit ≤ 9
            n = n*10 + maybe_digit
            pos += 1
        else
            return Nullable(n, false)
        end
    end
    Nullable(n)
end

"""
    tryparse_yyyymmdd(str)


"""
function tryparse_date(str::Vector{UInt8}, start)
    @assert length(str) ≥ start+8

    maybe_y = tryparse_base10_fixed(str, start, start+3)
    isnull(maybe_y) && @goto invalid

    maybe_m = tryparse_base10_fixed(str, start+4, start+5)
    isnull(maybe_m) && @goto invalid

    maybe_d = tryparse_base10_fixed(str, start+6, start+7)
    isnull(maybe_d) && @goto invalid

    # FIXME terminator is hardcoded
    str[start+8] == SEP || @goto invalid # unterminated

    y = get(maybe_y)
    m = max(get(maybe_m), 1)
    m ≤ 12 || @goto invalid
    d = max(get(maybe_d), 1)
    d ≤ Base.Dates.daysinmonth(y, m) || @goto invalid

    return Nullable(Date(y, m, d))

    @label invalid
    return Nullable{Date}()
end

function tryparse_skip(str::Vector{UInt8}, start, len = length(str))
    pos = start
    @inbounds while pos ≤ len
        str[pos] == SEP && return pos
        pos += 1
    end
    error("reached EOF")
end

function tryparse_gobble(str::Vector{UInt8}, start, len = length(str))
    stop = tryparse_skip(str, start)
    @view(str[start:(stop-1)]), stop
end

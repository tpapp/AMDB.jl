# separator between fields
const SEP = UInt8(';')

eol_error() = error("Reached end of line")

"""
    Nullable(d), pos = tryparse_base10_tosep(str, start, [stop])

Parse digits from `str` as an integer, until encountering `sep` or the position
`stop`.

Return the parsed integer as a `Nullable`, and the position of the *next*
unparsed character.

When encountering a character that is not a digit or `SEP`, return a null value.
"""
function tryparse_base10_tosep(str::Vector{UInt8}, start, len = length(str))
    n = 0
    z = UInt8('0')
    pos = start
    @inbounds while pos ≤ len
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
    eol_error()
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
    stop = start+8
    length(str) ≥ stop || eol_error()

    maybe_y = tryparse_base10_fixed(str, start, start+3)
    isnull(maybe_y) && @goto invalid

    maybe_m = tryparse_base10_fixed(str, start+4, start+5)
    isnull(maybe_m) && @goto invalid

    maybe_d = tryparse_base10_fixed(str, start+6, start+7)
    isnull(maybe_d) && @goto invalid

    # FIXME terminator is hardcoded
    str[stop] == SEP || @goto invalid # unterminated

    y = get(maybe_y)
    m = max(get(maybe_m), 1)
    m ≤ 12 || @goto invalid
    d = max(get(maybe_d), 1)
    d ≤ Base.Dates.daysinmonth(y, m) || @goto invalid

    return Nullable(Date(y, m, d)), stop

    @label invalid
    return Nullable{Date}(), stop
end

function tryparse_skip(str::Vector{UInt8}, start, len = length(str))
    pos = start
    @inbounds while pos ≤ len
        str[pos] == SEP && return pos
        pos += 1
    end
    eol_error()
end

function tryparse_gobble(str::Vector{UInt8}, start, len = length(str))
    stop = tryparse_skip(str, start, len)
    @view(str[start:(stop-1)]), stop
end

function parsefield end

struct SkipField end

parsefield(::SkipField, str, start) = true, tryparse_skip(str, start)

struct AccumulateField{T}
    values::Set{T}
end

AccumulateField(T) = AccumulateField(Set{T}())

Base.values(acc::AccumulateField) = acc.values

function parsefield(acc::AccumulateField{Int}, str, start)
    value, pos = tryparse_base10_tosep(str, start)
    !isnull(value) && push!(acc.values, get(value))
    !isnull(value), pos
end

function parsefield(acc::AccumulateField{Vector{UInt8}}, str, start)
    value, pos = tryparse_gobble(str, start)
    value ∈ acc.values || push!(acc.values, value)
    true, pos
end

function parsefield(acc::AccumulateField{Date}, str, start)
    value, pos = tryparse_date(str, start)
    !isnull(value) && push!(acc.values, get(value))
    !isnull(value), pos
end

parseline_(str, start) = nothing

parseline_(str, start, fieldparser) = parsefield(fieldparser, str, start)

function parseline_(str, start, fieldparser, fieldparsers...)
    status, start = parsefield(fieldparser, str, start)
    if status
        parseline_(str, start, fieldparsers...)
    else
        # report error
    end
end


parseline(str, fieldparsers) = parseline_(str, 1, fieldparsers...)

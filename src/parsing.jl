"""
    Nullable(d), pos = tryparse_base10_tosep(str, sep, start, [stop])

Parse digits from `str` as an integer, until encountering `sep` or the position
`stop`.

Return the parsed integer as a `Nullable`, and the position of the *next*
unparsed character.

When encountering a character that is not a digit or `sep`, return a null value.
"""
function tryparse_base10_tosep(str::Vector{UInt8}, sep::UInt8, start,
                               stop = length(str))
    n = 0
    z = UInt8('0')
    pos = start
    @inbounds while pos ≤ stop
        chr = str[pos]
        chr == sep && return Nullable(n, pos ≠ start), pos
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

tryparse_base10_tosep(str, sep::Char, start, stop = length(str)) =
    tryparse_base10_tosep(str, UInt8(sep), start, stop)

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

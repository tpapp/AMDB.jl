using ArgCheck

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

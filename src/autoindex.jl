using Parameters

struct AutoIndex{T,S}
    dict::Dict{T,S}
end

AutoIndex{T,S}() where {T,S} = AutoIndex(Dict{T,S}())

Base.length(ai::AutoIndex) = length(ai.dict)

function Base.getindex(ai::AutoIndex{T,S}, elt::E) where {T,S,E}
    @unpack dict = ai
    ix = get(dict, elt, zero(S))
    if ix == zero(S)
        v = length(dict) + one(S)
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

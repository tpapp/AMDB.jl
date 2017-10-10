######################################################################
# benchmark counting and accumulation
#
# a small experiment to benchmark
#
# 1. counting a lot of integers (observations ≫ individual counts)
#
# 2. counting a lot of byte vectors (views), observations ≫ unique vectors
#
# relevant decisions:
#
# 1. use DataStructures.counter, or a simple Dict
#
# 2. to check of the key is already in the collection,
#
# 3. to copy or not (for views)
#
#
# Benchmarks on: Julia v0.6, Intel(R) Core(TM) i7-6560U CPU @ 2.20GHz,
# Dell XPS 13 9350 (2016), 16 GB RAM
######################################################################

using DataStructures

"""
    rand_bytevector()

Return a vector of random bytes (restricted to letters), of random (short)
length.
"""
rand_bytevector() = rand(UInt8('a'):UInt8('z'), rand(2:4))

"""
    rand_NxM(M, N, f, g = identity)

1. generate `M` values using `f()`,
2. of these, draw `N` random values,
3. map them with `g`, return the result.
"""
function rand_NxM(M, N, f, g = identity)
    v0 = [f() for _ in 1:M]
    map(g, rand(v0, N))
end

function count_dict(strings::AbstractVector{T}) where {T}
    d = Dict{T, Int}()
    for s in strings
        d[s] = 1 + get(d, s, 0)
    end
    d
end

function count_dict_check(strings::AbstractVector{T}) where {T}
    d = Dict{T, Int}()
    for s in strings
        if haskey(d, s)
            d[s] += 1
        else
            d[s] = 1
        end
    end
    d
end

function count_dict_check_copy(strings::AbstractVector{<: SubArray{T}}) where {T}
    d = Dict{Vector{T}, Int}()
    for s in strings
        if haskey(d, s)
            d[s] += 1
        else
            d[copy(s)] = 1
        end
    end
    d
end

function count_accumulator(strings::AbstractVector{T}) where {T}
    d = counter(T)
    for s in strings
        push!(d, s)
    end
    d
end

function count_accumulator_convert(strings::AbstractVector{<: SubArray{T}}) where {T}
    d = counter(Vector{T})
    for s in strings
        push!(d, s)
    end
    d
end


function nocount(strings::AbstractVector{T}) where {T}
    d = Set{T}()
    for s in strings
        push!(d, s)
    end
    d
end

function nocount_check(strings::AbstractVector{T}) where {T}
    d = Set{T}()
    for s in strings
        s ∈ d || push!(d, s)
    end
    d
end

function nocount_check_copy(strings::AbstractVector{<: SubArray{T}}) where {T}
    d = Set{Vector{T}}()
    for s in strings
        s ∈ d || push!(d, copy(s))
    end
    d
end

######################################################################
# runtime
# number of elements
N = 100_000_000

######################################################################
# test: random strings
######################################################################

sv = rand_NxM(50, N, rand_bytevector, x -> view(x, :))

# compile
count_dict(sv[1:5]);
count_dict_check(sv[1:5]);
count_dict_check_copy(sv[1:5]);
count_accumulator(sv[1:5]);
count_accumulator_convert(sv[1:5]);
nocount(sv[1:5]);
nocount_check(sv[1:5]);
nocount_check_copy(sv[1:5]);

@time count_dict(sv);                # 12.13 s
@time count_dict_check(sv);          # 17.28 s
@time count_dict_check_copy(sv);     # 26.89 s
@time count_accumulator(sv);         # 12.44 s
@time count_accumulator_convert(sv); # 16.29 s
@time nocount(sv);                   # 6.73 s
@time nocount_check(sv);             # 5.96 s
@time nocount_check_copy(sv);        # 5.01 s

# conclusion: for just accummulating a set on views, check + copy is the fastest.
# Dict is competitive for counting.

######################################################################
# test: random integers
######################################################################

iv = rand_NxM(round(Int, N/10), N, ()->rand(Int))

# compile
count_dict(iv[1:5]);
count_dict_check(iv[1:5]);
count_accumulator(iv[1:5]);
nocount(iv[1:5]);
nocount_check(iv[1:5]);

@time count_dict(iv);                # 29.42 s
@time count_dict_check(iv);          # 31.82 s
@time count_accumulator(iv);         # 29.73 s
@time nocount(iv);                   # 15.54 s
@time nocount_check(iv);             # 14.01 s

# conclusion: nothing fancy is needed, just use a Dict

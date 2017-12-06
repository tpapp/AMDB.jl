using Base.Test

using ByteParsers: Skip
using DiscreteRanges

using AMDB:
    # errors
    FileError, FileErrors, log_error,
    # autoindexing
    AutoIndex,
    # dates
    AMDB_Date,
    # utilities
    narrowest_Int, to_narrowest_Int, column_parsers, TupleMap,
    # tuples
    join_dates, MultiSubs

# write your own tests here
@testset "paths" begin
    mktempdir() do dir
        withenv("AMDB_FILES" => dir) do
            @test AMDB.data_directory() == dir
            @test AMDB.data_path("foo") == joinpath(dir, "foo")
            @test AMDB.data_file(2000) ==
                joinpath(dir, "mon_ew_xt_uni_bus_00.csv.gz")
            open(joinpath(dir, "mon_ew_xt_uni_bus.cols.txt"), "w") do io
                write(io, "A;B;C\n")
            end
            @test AMDB.data_colnames() == ["A","B","C"]
        end
    end
end

@testset "error logging and printing" begin
    fe = FileErrors("foo.gz")
    @test repr(fe) == "foo.gz: 0 errors\n"
    @test count(fe) == 0
    log_error(fe, 99, b"bad;bad line", 5)
    @test count(fe) == 1
    @test repr(fe) == "foo.gz: 1 error\nbad;bad line\n    ^ line 99, byte 5\n"
end

@testset "auto indexing" begin
    aa = b"aa"
    bb = b"bb"
    ai = AutoIndex(Vector{UInt8}, Int8)
    @test ai(@view(aa[1:2])) == 1
    @test ai(bb) == 2
    @test ai(aa) == 1
    @test ai(bb) == 2
    @test ai(b"cc") == 3
    @test ai(@view aa[:]) == 1
    @test length(ai) == 3
    @test keys(ai) == [b"aa", b"bb", b"cc"]
    for i in 4:typemax(Int8)
        @test ai(UInt8[1,i]) == i
    end
    @test length(ai) == 127
    # check that we cannot add an element above capacity
    @test_throws AssertionError ai(b"this will not fit")
end

struct AddOne end

@testset "tuple map" begin
    (::AddOne)(x) = x + one(x)
    f = TupleMap((AddOne(), identity))
    @test @inferred(f((1,3))) == (2,3)
end

@testset "integer narrowing" begin
    ≖(x, y) = false             # also compare types
    ≖(x::Vector{T}, y::Vector{T}) where {T} = isequal(x, y)
    @test to_narrowest_Int([1,2,3]) ≖ Int8[1, 2, 3]
    @test to_narrowest_Int([-129,2,3]) ≖ Int16[-129, 2, 3]
    @test to_narrowest_Int([99, 32768]) ≖ Int32[99, 32768]
end

@testset "column parsers" begin
    c = column_parsers(["a", "b", "c", "d", "e"], ["b" => :b, "d" => :d])
    @test c == (Skip(), :b, Skip(), :d)
end

@testset "joindates" begin
    id = 99
    d1 = Date(1980, 1, 1)
    d2 = Date(1990, 1, 1)
    rest = (:misc, 42, :stuff)
    @test join_dates((id, d1, d2, rest...)) ==
        (id, DiscreteRange(AMDB_Date(d1), AMDB_Date(d2)), rest...)
end

@testset "multisubs" begin
    m = MultiSubs((1, 3), (x->x^2, x->x^3))
    @test @inferred(m((2, 3, 5))) ≡ (4, 3, 125)
end

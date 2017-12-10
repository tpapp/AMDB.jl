using Base.Test

using ByteParsers: Skip, parsenext, parsedtype, MaybeParsed
using DiscreteRanges: DiscreteRange

using AMDB:
    # errors
    FileError, FileErrors, log_error,
    # autoindexing
    AutoIndex, OrderedCounter,
    # dates
    AMDB_Date, DatePair,
    # utilities
    narrowest_Int, to_narrowest_Int,
    # tuples
    MultiSubs, get_positions

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

@testset "integer narrowing" begin
    ≖(x, y) = false             # also compare types
    ≖(x::Vector{T}, y::Vector{T}) where {T} = isequal(x, y)
    @test to_narrowest_Int([1,2,3]) ≖ Int8[1, 2, 3]
    @test to_narrowest_Int([-129,2,3]) ≖ Int16[-129, 2, 3]
    @test to_narrowest_Int([99, 32768]) ≖ Int32[99, 32768]
end

@testset "multisubs" begin
    m = MultiSubs((1, 3), (x->x^2, x->x^3))
    @test @inferred(m((2, 3, 5))) ≡ (4, 3, 125)
    @test get_positions(m) ≡ (1, 3)
end

@testset "DatePair parsing" begin
    str = b"20010101;20020327;"
    @test parsenext(DatePair(), str, 1, UInt8(';')) ≡
        MaybeParsed(19, DiscreteRange(AMDB_Date(Date(2001, 1, 1)),
                                      AMDB_Date(Date(2002, 3, 27))))
end

@testset "ordered counter" begin
    oc = OrderedCounter{Int, Int32}()
    @test oc(1) == 1
    @test oc(2) == 2
    @test oc(2) == 2
    @test oc(3) == 3
    @test oc(1) == 1
    @test collect(keys(oc)) == Int32[1, 2, 3]
    @test collect(values(oc)) == Int[2, 2, 1]
end

using AMDB
using Base.Test
using DataStructures

import AMDB:
    # errors
    FileError, FileErrors, log_error,
    # utilities
    narrowest_Int, to_narrowest_Int,
    # mmap handling
    cumsum2range, CumSumWrapper

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

@testset "integer narrowing" begin
    ≖(x, y) = false             # also compare types
    ≖(x::Vector{T}, y::Vector{T}) where {T} = isequal(x, y)
    @test to_narrowest_Int([1,2,3]) ≖ Int8[1, 2, 3]
    @test to_narrowest_Int([-129,2,3]) ≖ Int16[-129, 2, 3]
    @test to_narrowest_Int([99, 32768]) ≖ Int32[99, 32768]
end

@testset "cumsum index calculations" begin
    a = Int32[4, 3, 7]
    ca = cumsum(a)
    @test cumsum2range(ca, 1) ≡ UnitRange{Int32}(1,4)
    @test cumsum2range(ca, 2) ≡ UnitRange{Int32}(5,7)
    @test cumsum2range(ca, 3) ≡ UnitRange{Int32}(8:14)
    @test_throws BoundsError cumsum2range(ca, 0)
    @test_throws BoundsError cumsum2range(ca, 4)
    cwr = CumSumWrapper(ca)
    @test cwr[1] ≡ UnitRange{Int32}(1,4)
    @test cwr[2] ≡ UnitRange{Int32}(5,7)
    @test cwr[3] ≡ UnitRange{Int32}(8:14)
    @test_throws BoundsError cwr[0]
    @test_throws BoundsError cwr[4]
    @test length(cwr) == 3
    @test size(cwr) == (3,)
    @test eltype(cwr) == UnitRange{Int32}
end

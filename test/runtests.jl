using AMDB
using Base.Test

import AMDB:
    tryparse_base10_tosep,
    tryparse_base10_fixed,
    tryparse_date,
    tryparse_skip,
    tryparse_gobble

≅ = isequal

# made-up, not from the real dataset
const sampleline = b"9997;19800101;19900101;0;0;AA;BB;"

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

@testset "parsing integers" begin
    s = b"1970;1980;"
    @test tryparse_base10_tosep(s, 1) ≅ (Nullable(1970), 5)
    @test tryparse_base10_tosep(s, 6) ≅ (Nullable(1980), 10)
    @test tryparse_base10_tosep(b";;", 2) ≅ (Nullable{Int}(), 2)
    @test tryparse_base10_tosep(b";x;", 2) ≅ (Nullable{Int}(), 2)
    @test tryparse_base10_fixed(s, 1, 4) ≅ Nullable(1970)
    @test tryparse_base10_fixed(s, 6, 9) ≅ Nullable(1980)
    @test tryparse_base10_fixed(b"19x0", 1, 4) ≅ Nullable{Int}()
end

@testset "parsing dates" begin
    @test tryparse_date(b"19800101;", 1) ≅ Nullable(Date(1980, 1, 1))
    @test tryparse_date(b"19800000;", 1) ≅ Nullable(Date(1980, 1, 1))
    @test tryparse_date(b"19809901;", 1) ≅ Nullable{Date}()
end

@testset "parsing or skipping strings" begin
    @test tryparse_skip(b"12;1234;", 4) ≅ 8
    @test tryparse_gobble(b"12;1234;", 4) ≅ (b"1234", 8)
end

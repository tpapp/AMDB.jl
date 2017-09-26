using AMDB
using Base.Test

import AMDB:
    EMPTY, EOL, INVALID,
    parse_base10_tosep,
    parse_base10_fixed,
    parse_date,
    parse_skip,
    parse_gobble,
    accumulate_field,
    SkipField,
    AccumulateField

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
    @test parse_base10_tosep(s, 1) == (1970, 5)
    @test parse_base10_tosep(s, 6) == (1980, 10)
    @test parse_base10_tosep(b";;", 2)[2] == EMPTY
    @test parse_base10_tosep(b";x;", 2)[2] == INVALID
    @test parse_base10_fixed(s, 1, 4) == (1970, 5)
    @test parse_base10_fixed(s, 6, 9) == (1980, 10)
    @test parse_base10_fixed(b"19x0", 1, 4)[2] == INVALID
end

@testset "parsing dates" begin
    @test parse_date(b"xx;19800101;", 4) == (Date(1980, 1, 1), 12)
    @test parse_date(b"xx;19800000;", 4) == (Date(1980, 1, 1), 12)
    @test parse_date(b"xx;19809901;", 4)[2] == INVALID
end

@testset "parsing or skipping strings" begin
    @test parse_skip(b"12;1234;", 4) == 8
    @test parse_gobble(b"12;1234;", 4) == (b"1234", 8)
end

@testset "field parsers" begin
    @test accumulate_field(SkipField(), b"1980;", 1) == 5
    @test accumulate_field(SkipField(), b"1980;1990;", 6) == 10
    acc = AccumulateField(Int64)
    @test accumulate_field(acc, b"1980;", 1) == 5
    @test accumulate_field(acc, b"1980;1990;", 6) == 10
    @test accumulate_field(acc, b"1980;1990", 6) == EOL
    @test accumulate_field(acc, b";", 1) == EMPTY
    @test sort(collect(values(acc))) == [1980, 1990]
    acc = AccumulateField(Date)
    @test accumulate_field(acc, b"19800101;", 1) == 9
    @test accumulate_field(acc, b"19800101;19900202;", 10) == 18
    @test accumulate_field(acc, b"19800101", 1) == EOL
    @test accumulate_field(acc, b";", 1) == EOL
    @test sort(collect(values(acc))) == [Date(1980, 1, 1), Date(1990, 2, 2)]
end

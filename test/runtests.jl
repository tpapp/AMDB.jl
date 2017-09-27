using AMDB
using Base.Test

import AMDB:
    EMPTY, EOL, INVALID,
    ByteVector,
    parse_base10_tosep,
    parse_base10_fixed,
    parse_date,
    parse_skip,
    parse_gobble,
    accumulate_field,
    accumulate_line,
    SKIPFIELD

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

@testset "field accumulation" begin
    @test accumulate_field(b"1980;", 1, SKIPFIELD) == 5
    @test accumulate_field(b"1980;1990;", 6, SKIPFIELD) == 10
    acc = Set{Int64}()
    @test accumulate_field(b"1980;", 1, acc) == 5
    @test accumulate_field(b"1980;1990;", 6, acc) == 10
    @test accumulate_field(b"1980;1990", 6, acc) == EOL
    @test accumulate_field(b";", 1, acc) == EMPTY
    @test sort(collect(acc)) == [1980, 1990]
    acc = Set{Date}()
    @test accumulate_field(b"19800101;", 1, acc) == 9
    @test accumulate_field(b"19800101;19900202;", 10, acc) == 18
    @test accumulate_field(b"19800101", 1, acc) == EOL
    @test accumulate_field(b";", 1, acc) == EOL
    @test sort(collect(acc)) == [Date(1980, 1, 1), Date(1990, 2, 2)]
end

@testset "line accumulation" begin
    ids = Set{Int}()
    dates = Set{Date}()
    str1 = Set{ByteVector}()
    str2 = Set{ByteVector}()
    accumulators = (ids, dates, dates, SKIPFIELD, SKIPFIELD, str1, str2)
    accumulate_line(b"9997;19800101;19900101;0;0;CC;BB;", accumulators)
    accumulate_line(b"1212;19600101;20000505;0;0;AA;DD;", accumulators)
    @test sort(collect(ids)) == [1212, 9997]
    @test sort(collect(dates)) ==
        Date.(["1960-01-01", "1980-01-01", "1990-01-01", "2000-05-05"])
    @test sort(collect(str1), lt=lexless) == [b"AA", b"CC"]
    @test sort(collect(str2), lt=lexless) == [b"BB", b"DD"]
end

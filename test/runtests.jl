using AMDB_IHS
using Base.Test

# write your own tests here
@testset "paths" begin
    mktempdir() do dir
        withenv("AMDB_FILES" => dir) do
            @test amdb_files_directory() == dir
            @test amdb_data_path("foo") == joinpath(dir, "foo")
            @test amdb_data_file(2000) ==
                joinpath(dir, "mon_ew_xt_uni_bus_00.csv.gz")
            open(joinpath(dir, "mon_ew_xt_uni_bus.cols.txt"), "w") do io
                write(io, "A;B;C\n")
            end
            @test amdb_colnames() == ["A","B","C"]
        end
    end
end

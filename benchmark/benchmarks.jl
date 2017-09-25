using PkgBenchmark
using AMDB

import AMDB: tryparse_base10_tosep, tryparse_base10_fixed

@benchgroup "parsing primitives" begin
    str = b"1980;"
    @bench "parse tosep" tryparse_base10_tosep($str, UInt8(';'), 1)
    @bench "parse fixed" tryparse_base10_fixed($str, 1, 4)
end

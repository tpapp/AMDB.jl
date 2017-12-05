# install unregistered packages
Pkg.clone("https://github.com/tpapp/RaggedData.jl.git")
Pkg.clone("https://github.com/tpapp/ByteParsers.jl.git")
Pkg.clone("https://github.com/tpapp/DiscreteRanges.jl.git")
Pkg.clone("https://github.com/tpapp/LargeColumns.jl.git")
Pkg.clone("https://github.com/tpapp/FlexDates.jl.git")
Pkg.clone("https://github.com/tpapp/WallTimeProgress.jl.git")
# build and test
Pkg.clone(pwd())
Pkg.build("AMDB")
Pkg.test("AMDB"; coverage=true)

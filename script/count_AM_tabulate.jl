######################################################################
# tabulate the results of count_AM_by_year.jl, save it as a CSV file
######################################################################

using AMDB_IHS
using JLD
using DocStringExtensions

"""
    $(SIGNATURES)

Normalized values in a dictionary, returned in the order provided by `keys`. Missing keys are treated as `0`.
"""
function normalized_ordered(dict, keys)
    total = sum(values(dict))
    [get(dict, key, 0)/total for key in keys]
end

status_counts = load(joinpath(amdb_files_directory(),
                              "status_counts.jld"))["status_counts"]

# sum all years
total = Dict{String, Int64}()
for sc in values(status_counts)
    for (key, value) in sc
        total[key] = get(total, key, 0) + value
    end
end

ordered_keys = first.(sort(collect(total), by = last, rev = true))

years = sort(collect(keys(status_counts)))

table = vcat(hcat("","TOTAL",string.(years)...),
             hcat(ordered_keys,
                  normalized_ordered(total, ordered_keys),
                  [normalized_ordered(status_counts[year], ordered_keys)
                   for year in years]...))

writedlm(joinpath(amdb_files_directory(), "status_counts.csv"), table, ',')

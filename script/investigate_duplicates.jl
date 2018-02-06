using AMDB
using DocStringExtensions
using Distributions
using DataStructures
using ProgressMeter


# data part

# read the data
data = AMDB.collated_dataset("collated"); # load the data

function count_duplicates(data, individual_index)
    stichtag = individual_columns(data, individual_index, [:STICHTAG])[1]
    mis = get_mis.(stichtag)
    length(mis) - length(unique(mis))
end

function individuals_with_duplicates(data)
    duplicates = Vector{Tuple{Int, Int}}() # index, how many
    @showprogress for i in indices(data.ix, 1)
        d = count_duplicates(data, i)
        if d > 0
            push!(duplicates, (i, d))
        end
    end
    duplicates
end

function select_duplicates(v)
    c = counter(v)
    map(elt -> c[elt] > 1, v)
end

function duplicate_observations(data, individual_index)
    df = individual_df(data, individual_index)
    dup = select_duplicates(df[:STICHTAG])
    df[dup, :]
end

# looking at one individual
count_duplicates(data, 400)
dd = duplicate_observations(data, 400)

showall(individual_df(data, 400))

dup = individuals_with_duplicates(data)

count(d -> last(d) > 10, dup) / length(data.ix)
count(d -> last(d) > 20, dup) / length(data.ix)

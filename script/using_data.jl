using AMDB                      # data path and date type
using FlexDates                 # dates, compressed into Int16
using DiscreteRanges            # for ranges of dates
using JLD2                      # for the metadata
using FileIO                    # loading JLD2
using RaggedData                # ragged vectors
using LargeColumns              # large columns mapped to disk
using IndirectArrays            # for AM spells

######################################################################
# these two functions can be used to load the dataset
######################################################################

"""
    dataset_AM_dates(; dir = "collated")

Load the collated dataset which contains the following two columns:

1. strings for Arbeitsmarkt spells (as an IndirectArray)

2. date spans (as DiscreteRange{FlexDate}).
"""
function dataset_AM_dates(; dir = "collated")
    collated = MmappedColumns(data_path(dir))
    AM_ix_raw, dates = collated.columns
    meta = load(meta_path(collated, "meta.jld2"))
    AM_keys = meta["AM_keys"]
    RaggedColumns(meta["ix"], (IndirectArray(AM_ix_raw, AM_keys), dates))
end

"""
    AM_dates_keys(data)

Return the list of all spell types (strings) of a dataset loaded by
`dataset_AM_dates()`.
"""
AM_dates_keys(data::RaggedColumns) = data.columns[1].values

######################################################################
# runtime
######################################################################

data = dataset_AM_dates();

# count all the different spell types by total time spent in each
function count_totals(data, AM_keys = AM_dates_keys(data))
    d = Dict(key => 0 for key in AM_keys)
    for (spell_types, spell_ranges) in data # iterate over individuals
        for (spell_type, spell_range) in zip(spell_types, spell_ranges) # iterate over spells
            d[spell_type] += length(spell_range)
        end
    end
    d
end

@time tot = count_totals(data)  # about 2 minutes

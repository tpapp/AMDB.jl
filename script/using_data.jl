using AMDB:
    collated_dataset, data_path,
    count_total_length, Proportions, aggregate_tail,
    dump_latex
using IndirectArrays: IndirectArray
using StatsBase: fit, Histogram
using Plots; pgfplots()

data = collated_dataset("collated_subset")
results_dir = data_path("results")
mkpath(results_dir)
cd(results_dir)


# count all the different spell types by total time spent in each

c = count_total_length(data[:STARTEND], data[:AM])
p = Proportions(c)
pa = aggregate_tail(p, 10, "rest")
dump_latex("spell_categories.tex", aggregate_tail(p, 12, "rest"))


# histogram of spell counts
y = length.(data[:ix])
spell_counts = fit(Histogram, y, closed = :right, nbins = 100)
plot(spell_counts, xlim = (0,30), xlab = "spells by individual (non-merged)", legend = false)
savefig("spell_counts.tex")


# spell coverage
individual_coverage(startend) = sum(length.(startend))
y = collect(sum(length.(data[:STARTEND][r])) for r in data[:ix])

coverage_hist = fit(Histogram, y / (16*365), closed = :left)
plot(coverage_hist, xlab = "spell coverage", legend = false)

a = data[:ix][18]
length(a)

length(data[:ix][300])

import Base.Markdown
import DiscreteRanges: DiscreteRange
import FlexDates: FlexDate

_fmt(x) = string(x)

_fmt(x::DiscreteRange{<: FlexDate}) =
    string(convert(Date, x.left)) * "…" * string(convert(Date, x.right))

function individual_history(data, index, column_names...)
    r = data[:ix][index]
    column_names = [column_names...]
    rows = [getindex.(AMDB.nicelabels, column_names)]
    cols = getindex.(data, column_names)
    for i in r
        push!(rows, @. _fmt(getindex(cols, i)))
    end
    Markdown.MD(Markdown.Table(rows, fill(:r, length(cols))))
end

individual_history(data, 20, :PENR, :STARTEND, :AM, :BENR, :)
index = 19
column_names = (:PENR, :STARTEND)

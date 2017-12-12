using AMDB:
    collated_dataset, data_path,
    count_total_length, Proportions, aggregate_tail,
    dump_latex, individual_history
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
plot(spell_counts, xlim = (0,30), xlab = "spells by individual (unmerged)", legend = false)
savefig("spell_counts.tex")


# spell coverage
individual_coverage(startend) = sum(length.(startend))
y = collect(sum(length.(data[:STARTEND][r])) for r in data[:ix])
coverage_hist = fit(Histogram, y / (16*365), closed = :left, nbins = 100)
plot(coverage_hist, xlab = "spell coverage (unmerged)", xlim = (0,20), legend = false)
savefig("spell_coverage.tex")


# inspect individuals
cols = [:STARTEND, :AM, :BENR, :SUM_MA, :NACE, :RGS, :AVG_BMG]

H = individual_history(data, 2624, cols...)
dump_latex("ind1.tex", H)

H = individual_history(data, 9168197, cols...)
dump_latex("ind2.tex", H)

H = individual_history(data, 6831135, cols...)
dump_latex("ind3.tex", H)

H = individual_history(data, 1466249, cols...) # multiple wages
dump_latex("ind4.tex", H)

H = individual_history(data, 7827568, cols...) # top-coded emp num
dump_latex("ind5.tex", H)

# draw from this and save interesting ones
H = individual_history(data, rand(data[:PENR]), cols...)

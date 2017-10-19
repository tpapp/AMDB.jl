using JLD

meta_records_file(base_filename) = data_path(base, "_meta.jld")

function first_pass_filenames(base_filename)
    fn(part) = data_path("$(base_filename)_$(part).bin")
    fn("id"), fn("AM_ix"), fn("date_start"), fn("date_stop")
end

function first_pass_streams(base_filename, mode)
    map(fn -> open(fn, mode), first_pass_filenames(base_filename))
end

# function first_pass_mmap(base_filename, N, mode = "r+")
#     id, AM_ix, date_start, date_stop = first_pass_streams(base_filename, mode)
#     mmapped_(stream, T) = Mmap.mmap(stream, Vector{T}, (N,))
#     (mmapped_(id, Int32), mmapped_(AM_ix, Int8),
#      mmapped_(date_start, Date), mmapped_(date_stop, Date))
# end


function mmapped_vector(filename, T::Type, len::Int, mode = "r+")
    stream = open(data_path(filename), mode)
    Mmap.mmap(stream, Vector{T}, (len,))
end



# function second_pass_mmap(base_filename, N, mode = "r+")
#     function mmapped_(part, T)
#         Mmap.mmap(open(data_path("$(base_filename)_$(part).bin")))
# end

function mmapped_arrays(base_filename, N, mode = "r")
    filename_(part) = data_path(base_filename, "_", part)
    mmapped_(part, T) = Mmmap.mmap(open(filename_(part), mode), Array{T}, (N,))
    (mmapped_("id", Int32),
     mmapped_("cumsum", Int32),
     mmapped_("spell_start", Date),
     mmapped_("spell_stop", Date),
     mmapped_("spell_raw_type", Date))
end

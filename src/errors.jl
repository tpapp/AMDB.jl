######################################################################
# error logging
######################################################################

using EnglishText
using Parameters

struct FileError
    line_number::Int
    line_content::Vector{UInt8}
    line_position::Int
end

function Base.show(io::IO, file_error::FileError)
    @unpack line_number, line_content, line_position = file_error
    println(io, String(line_content))
    print(io, " "^(line_position - 1))
    println(io, "^ line $(line_number), byte $(line_position)")
end

struct FileErrors{S}
    filename::S
    errors::Vector{FileError}
end

FileErrors(filename::String) = FileErrors(filename, Vector{FileError}(0))

function log_error(file_errors::FileErrors, line_number, line_content,
                   line_position)
    push!(file_errors.errors,
          FileError(line_number, line_content, line_position))
end

function Base.show(io::IO, file_errors::FileErrors)
    @unpack filename, errors = file_errors
    error_quantity = ItemQuantity(length(errors), "error")
    println(io, "$filename: $(error_quantity)")
    for e in errors
        show(io, e)
    end
end

Base.count(file_errors::FileErrors) = length(file_errors.errors)

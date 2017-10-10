using CodecZlib
using ByteParsers
using WallTimeProgress

"""
   
"""
function process_stream(io::IO, parser, f, errors::FileErrors;
                        tracker_period = 10_000_000, max_lines = -1)
    tracker = WallTimeTracker(tracker_period; item_name = "line")
    while !eof(io) && (max_lines < 0 || count(tracker) < max_lines)
        line_content = readuntil(io, 0x0a)
        record = parsenext(parser, line_content, 1, UInt8(';'))
        if isparsed(record)
            f(unsafe_get(record))
        else
            log_error(errors, count(tracker), line_content, getpos(record))
        end
        increment!(tracker)
    end
end

function process_file(filename, parser, f; args...)
    io = GzipDecompressionStream(open(filename))
    errors = FileErrors(filename)
    process_stream(io, parser, f, errors; args...)
    errors
end

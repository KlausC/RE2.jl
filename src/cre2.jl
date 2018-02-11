# This file is a part of Julia. License is MIT: https://julialang.org/license

## low-level cre2 interface to RE2 ##

module CRE2
using Libdl        

include("cre2_h.jl")

const RE2LIB = "libcre2"

function __init__()
    push!(DL_LOAD_PATH, "/usr/local/lib")
end

function new_options(options::UInt32, mem::Integer=DEFAULT_MAX_MEM)
    copt = ccall((:cre2_opt_new, RE2LIB), Ptr{Cvoid}, ())
    set_options(copt, options, mem)
    copt
end

function free_options(copt::Ptr{Cvoid})
    if copt != Ptr{Cvoid}(0)
        ccall((:cre2_opt_delete, RE2LIB), Cvoid, (Ptr{Cvoid},), copt)
    end
end

function set_options(copt::Ptr{Cvoid}, options::UInt32, mem)
    vencoding = options & LATIN1 != 0 ? Latin1 : UTF8
    vlongest = options & LONGEST_MATCH == 0 ? 0 : 1
    vlogerrors = options & LOG_ERRORS == 0 ? 0 : 1
    vliteral = options & LITERAL == 0 ? 0 : 1
    vnevernl = options & NEVER_NL == 0 ? 0 : 1
    vdotnl = options & DOTALL == 0 ? 0 : 1
    vnevercap = options & NEVER_CAPTURE == 0 ? 0 : 1
    vcase = options & CASELESS == 0 ? 1 : 0
    vposix = options & POSIX_SYNTAX == 0 ? 0 : 1
    vperlclass = options & PERL_CLASSES != 0 ? 1 : 0
    vwordbound = options & WORD_BOUNDARY != 0 ? 1 : 0
    voneline = options & MULTILINE != 0 ? 0 : 1

    ccall((:cre2_opt_set_encoding, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vencoding)
    ccall((:cre2_opt_set_longest_match, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vlongest)
    ccall((:cre2_opt_set_log_errors, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vlogerrors)
    ccall((:cre2_opt_set_literal, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vliteral)
    ccall((:cre2_opt_set_never_nl, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vnevernl)
    ccall((:cre2_opt_set_dot_nl, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vdotnl)
    ccall((:cre2_opt_set_never_capture, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vnevercap)
    ccall((:cre2_opt_set_case_sensitive, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vcase)
    ccall((:cre2_opt_set_posix_syntax, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vposix)
    ccall((:cre2_opt_perl_classes, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vperlclass)
    ccall((:cre2_opt_word_boundary, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, vwordbound)
    ccall((:cre2_opt_one_line, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, voneline)

    ccall((:cre2_opt_set_max_mem, RE2LIB), Cvoid, (Ptr{Nothing}, Cint), copt, mem)
    copt
end

function get_options(copt::Ptr{Cvoid})
    vencoding = ccall((:cre2_opt_encoding, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vlongest = ccall((:cre2_opt_longest_match, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vlogerrors = ccall((:cre2_opt_log_errors, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vliteral = ccall((:cre2_opt_literal, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vnevernl = ccall((:cre2_opt_never_nl, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vdotnl = ccall((:cre2_opt_dot_nl, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vnevercap = ccall((:cre2_opt_never_capture, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vcase = ccall((:cre2_opt_case_sensitive, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vposix = ccall((:cre2_opt_posix_syntax, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vperlclass = ccall((:cre2_opt_perl_classes, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    vwordbound = ccall((:cre2_opt_word_boundary, RE2LIB), Cuint, (Ptr{Nothing},), copt)
    voneline = ccall((:cre2_opt_one_line, RE2LIB), Cuint, (Ptr{Nothing},), copt)
   
    op = UInt32(0)
    vencoding == Latin1 && (op |= LATIN1)
    vlongest != 0 && (op |= LONGEST_MATCH)
    vlogerrors != 0 && (op |= LOG_ERRORS)
    vliteral != 0 && (op |= LITERAL)
    vnevernl != 0 && (op |= NEVER_NL)
    vdotnl != 0 && (op |= DOTALL)
    vnevercap != 0 && (op |= NEVER_CAPTURE)
    vcase == 0 && (op |= CASELESS)
    vposix != 0 && (op |= POSIX_SYNTAX)
    vperlclass != 0 && (op |= PERL_CLASSES)
    vwordbound != 0 && (op |= WORD_BOUNDARY)
    voneline == 0 && (op |= MULTILINE)
    op
end

function get_maxmem(copt::Ptr{Cvoid})
    ccall((:cre2_opt_max_mem, RE2LIB), Cuint, (Ptr{Cvoid},), copt)
end

function get_program_size(regex::Ptr{Cvoid})
    ccall((:cre2_program_size, RE2LIB), Cuint, (Ptr{Cvoid},), regex)
end

# supported options for different use cases

function error_code(regex::Ptr{Cvoid})
    regex == C_NULL && error("NULL regex object")
    res = ccall((:cre2_error_code, RE2LIB), Cint, (Ptr{Cvoid},), regex)
    Int(res)
end

function error_string(regex::Ptr{Cvoid})
    regex == C_NULL && error("NULL regex object")
    res = ccall((:cre2_error_string, RE2LIB), Cstring, (Ptr{Cvoid},), regex)
    unsafe_string(res)
end

function get_ovec(match_data)
    ptr = ccall((:pcre2_get_ovector_pointer_8, RE2LIB), Ptr{Csize_t},
                (Ptr{Cvoid},), match_data)
    n = ccall((:pcre2_get_ovector_count_8, RE2LIB), UInt32,
              (Ptr{Cvoid},), match_data)
    unsafe_wrap(Array, ptr, 2n, own = false)
end

function compile(pattern::AbstractString, options::Ptr{Cvoid})
    errno = Ref{Cint}(0)
    erroff = Ref{Csize_t}(0)
    re_ptr = ccall((:cre2_new, RE2LIB), Ptr{Cvoid},
                   (Ptr{UInt8}, Csize_t, Ptr{Cvoid}),
                   pattern, sizeof(pattern), options)
    if re_ptr == C_NULL
        error("RE2 compilation error: memory allocation failed")
    end
    errno = error_code(re_ptr)
    if errno != NO_ERROR
        es = error_string(re_ptr)
        error("RE2 compilation error $errno: $es")
    end
    re_ptr
end

free_re(re) = ccall((:cre2_delete, RE2LIB), Cvoid, (Ptr{Cvoid},), re)

function exec(re, text, offset, options, match_data, nmatch_data::Integer=-1)
    text_length::Cint = sizeof(text)
    text = pointer(text)
    start_pos::Cint = offset
    end_pos::Cint = min(text_length, typemax(Cint))
    nmatch_data::Cint = nmatch_data < 0 ? length(match_data) ÷ 2 : Cint(nmatch_data)
    match_data = pointer(match_data)

    rc = ccall((:cre2_match, RE2LIB), Cint,
            (Ptr{Cvoid}, Ptr{UInt8}, Cint, Cint, Cint, Cuint, Ptr{Cvoid}, Cint),
            re, text, text_length, start_pos, end_pos, options, match_data, nmatch_data)

    rc != 0
end

function num_capturing_groups(re)
    n = ccall((:cre2_num_capturing_groups, RE2LIB), Cint, (Ptr{Cvoid},), re)
    n < 0 && error("no capturing groups - invalid regex") 
    n
end

function create_match_data(re)
    n = num_capturing_groups(re)
    fill(C_NULL, n * 2 + 2)
end

function group_number_from_name(re, name)
  ccall((:cre2_find_named_capturing_groups, RE2LIB), Cint, (Ptr{Cvoid}, Cstring), re, name)
end

function substring_length_bynumber(match_data, number)
    n = length(match_data) ÷ 2 - 1
    0 <= number <= n || error("no data for substring $number")
    len = match_data[number*2+2]
    convert(Int, len)
end

function substring_copy_bynumber(match_data, number, buf, buf_size)
    n = length(match_data) ÷ 2 - 1
    0 <= number <= n || error("no data for substring $number")
    p = Ptr{UInt8}(match_data[number*2+1])
    unsafe_copyto!(buf, p, buf_size)
    convert(Int, buf_size-1)
end

function capture_names(re::Ptr{Cvoid}, pat::AbstractString)
    names = Dict{Int,SubString}()
    i = start(pat)
    n = 0
    while !done(pat, i)
        c, i = next(pat, i)
        if c == '<'
            n = i
        elseif c == '>' && n != 0
            name = SubString(pat, n, prevind(pat, i, 2))
            ix = group_number_from_name(re, name)
            if ix >= 0
                names[ix] = name
            end
            n = 0
        end
    end
    names
end

end # module

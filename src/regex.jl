# This file is a part of Julia. License is MIT: https://julialang.org/license

## object-oriented RE2 interface via cre2 ##

export @rr_str, Regex2, Regex2Match
import Base: compile, contains, match, matchall, findfirst, findnext, eachmatch

import Base: getindex, ==, show, print_quoted_literal, ensureroom
import Base: eltype, next, done, start, IteratorSize, SizeUnknown, SubstitutionString

include("cre2.jl")

export        ANCHORED, ENDANCHORED,
              LOG_ERRORS, LATIN1, LONGEST_MATCH, LITERAL, NEVER_NL, DOTALL, NEVER_CAPTURE,
              CASELESS, POSIX_SYNTAX, PERL_CLASSES, WORD_BOUNDARY, MULTILINE

import .CRE2: ANCHORED, ENDANCHORED,
              LOG_ERRORS, LATIN1, LONGEST_MATCH, LITERAL, NEVER_NL, DOTALL, NEVER_CAPTURE,
              CASELESS, POSIX_SYNTAX, PERL_CLASSES, WORD_BOUNDARY, MULTILINE

const DEFAULT_COMPILER_OPTS = PERL_CLASSES | WORD_BOUNDARY
const DEFAULT_MATCH_OPTS = ANCHORED & ~ANCHORED

mutable struct Regex2
    pattern::String
    compile_options::UInt32
    match_options::UInt32
    regex::Ptr{Cvoid}
    match_data::Vector{Ptr{Cvoid}}

    function Regex2(pattern::AbstractString, compile_options::Integer,
                   match_options::Integer)

        pattern = String(pattern)
        compile_options = UInt32(compile_options & ~LOG_ERRORS) # silently ignore
        match_options = UInt32(match_options)
        if (compile_options & ~CRE2.COMPILE_MASK) != 0
            throw(ArgumentError("invalid regex compile options: $compile_options"))
        end
        if (match_options & ~CRE2.EXECUTE_MASK) !=0
            throw(ArgumentError("invalid regex match options: $match_options"))
        end
        if compile_options & POSIX_SYNTAX == 0
            compile_options |= (PERL_CLASSES|WORD_BOUNDARY)
            compile_options &= ~MULTILINE
        end
        re = new(pattern, compile_options, match_options, C_NULL, Ptr{Cvoid}[])
        compile(re)

        finalizer(re) do re
            re.regex == C_NULL || CRE2.free_re(re.regex)
        end
        re
    end
end

using Printf
function Regex2(pattern::AbstractString, flags::AbstractString)
    options = DEFAULT_COMPILER_OPTS
    for f in flags
        options |= f=='i' ? CASELESS  :
                   f=='m' ? MULTILINE :
                   f=='s' ? DOTALL    :
                   f=='l' ? LONGEST_MATCH  :
                   f=='p' ? POSIX_SYNTAX  :
                   throw(ArgumentError("unknown regex flag: $f"))
    end
    Regex2(pattern, options, DEFAULT_MATCH_OPTS)
end
Regex2(pattern::AbstractString) = Regex2(pattern, DEFAULT_COMPILER_OPTS, DEFAULT_MATCH_OPTS)

function compile(re::Regex2)
    if re.regex == C_NULL
        copts = CRE2.new_options(re.compile_options)
        re.regex = CRE2.compile(re.pattern, copts)
        re.match_data = CRE2.create_match_data(re.regex)
        CRE2.free_options(copts)
    end
    re
end

"""
    @rr_str -> Regex2

Construct a regex, such as `rr"^[a-z]*\$"`. The regex also accepts one or more flags,
listed after the ending quote, to change its behaviour:

- `i` enables case-insensitive matching
- `m` treats the `^` and `\$` tokens as matching the start and end of individual lines, as
  opposed to the whole string.
- `s` allows the `.` modifier to match newlines.
- `l` enables "longest match mode".
- `p` enables "POSIX syntax" - like egrep.

For example, this regex has all three flags enabled:

```jldoctest
julia> match(rr"a+.*b+.*?d\$"ism, "Goodbye,\\nOh, angry,\\nBad world\\n")
Regex2Match("angry,\\nBad world")
```
"""
macro rr_str(pattern, flags...) Regex2(pattern, flags...) end

function show(io::IO, re::Regex2)
    opts = re.compile_options
    imsx = CASELESS|MULTILINE|DOTALL|LONGEST_MATCH|POSIX_SYNTAX|LOG_ERRORS
    opts & POSIX_SYNTAX == 0 && ( imsx |= PERL_CLASSES|WORD_BOUNDARY )

    if opts & ~imsx == 0
        print(io, "rr")
        print_quoted_literal(io, re.pattern)
        if opts & CASELESS != 0; print(io, 'i'); end
        if opts & DOTALL != 0; print(io, 's'); end
        if opts & LONGEST_MATCH != 0; print(io, 'l'); end
        if opts & POSIX_SYNTAX != 0; print(io, 'p'); end
        if opts & POSIX_SYNTAX != 0
            if (opts & MULTILINE) != 0; print(io, 'm'); end
        end
    else
        print(io, "Regex2(")
        show(io, re.pattern)
        print(io, ',')
        show(io, opts)
        print(io, ')')
    end
end

# TODO: map offsets into strings in other encodings back to original indices.
# or maybe it's better to just fail since that would be quite slow

struct Regex2Match
    match::SubString{String}
    captures::Vector{Union{Nothing,SubString{String}}}
    offset::Int
    offsets::Vector{Int}
    regex::Regex2
end

function show(io::IO, m::Regex2Match)
    print(io, "Regex2Match(")
    show(io, m.match)
    idx_to_capture_name = CRE2.capture_names(m.regex.regex, m.regex.pattern)
    if !isempty(m.captures)
        print(io, ", ")
        for i = 1:length(m.captures)
            # If the capture group is named, show the name.
            # Otherwise show its index.
            capture_name = get(idx_to_capture_name, i, i)
            print(io, capture_name, "=")
            show(io, m.captures[i])
            if i < length(m.captures)
                print(io, ", ")
            end
        end
    end
    print(io, ")")
end

# Capture group extraction
getindex(m::Regex2Match, idx::Integer) = m.captures[idx]
function getindex(m::Regex2Match, name::AbstractString)
    idx = CRE2.group_number_from_name(m.regex.regex, name)
    idx <= 0 && error("no capture group named $name found in regex")
    m[idx]
end
getindex(m::Regex2Match, name::Symbol) = m[string(name)]

function contains(s::AbstractString, r::Regex2, offset::Integer=0)
    compile(r)
    return CRE2.exec(r.regex, String(s), offset, get_match_options(r), r.match_data)
end

function contains(s::SubString, r::Regex2, offset::Integer=0)
    compile(r)
    return CRE2.exec(r.regex, s, offset, get_match_options(r), r.match_data)
end

(r::Regex2)(s) = contains(s, r)

"""
    match(r::Regex2, s::AbstractString[, idx::Integer[, addopts]])

Search for the first match of the regular expression `r` in `s` and return a `Regex2Match`
object containing the match, or nothing if the match failed. The matching substring can be
retrieved by accessing `m.match` and the captured sequences can be retrieved by accessing
`m.captures` The optional `idx` argument specifies an index at which to start the search.
The optional addopts can be zero, `ANCHORED`, or `ANCHORED | ENDANCHORED`. `ENDANCHORED`
allone is not supported.

# Examples
```jldoctest
julia> rx = rr"a(.)a"
r"a(.)a"

julia> m = match(rx, "cabac")
Regex2Match("aba", 1="b")

julia> m.captures
1-element Array{Union{Nothing, SubString{String}},1}:
 "b"

julia> m.match
"aba"

julia> match(rx, "cabac", 3) == nothing
true
```
"""
function match end

function match(re::Regex2, str::Union{SubString{String}, String},
               idx::Integer, add_opts::Integer=0)

    compile(re)
    opts = get_match_options(re.match_options | UInt32(add_opts))
    CRE2.exec(re.regex, str, idx-1, opts, re.match_data) || return nothing
    md = re.match_data
    pstr = pointer(str)
    n = div(length(md),2) - 1
    ix1, ix2 = substrind(str, md, 0)
    mat = SubString(str, ix1, ix2)
    cap = Union{Nothing,SubString{String}}[md[2i+1] == Ptr{UInt8}(0) ?
                                nothing : substr(str, md, i) for i=1:n]
    
    off = Int[ substrind(str, md, i)[1] for i=1:n ]
    Regex2Match(mat, cap, ix1, off, re)
end

match(r::Regex2, s::AbstractString) = match(r, s, firstindex(s))
match(r::Regex2, s::AbstractString, i::Integer) = throw(ArgumentError(
    "regex matching is only available for the String type; use String(s) to convert"
))

function get_match_options(optmask::UInt32)
    opt = CRE2.UNANCHORED
    optmask & ANCHORED != 0 && ( opt = max(opt, CRE2.ANCHOR_START) )
    optmask & ENDANCHORED != 0 && ( opt = max(opt, CRE2.ANCHOR_BOTH) )
    opt
end
get_match_options(re::Regex2) = get_match_options(re.match_options)

function substrind(str::Union{String,SubString{String}}, md::Vector{Ptr{Cvoid}}, i::Int)
    ix1 = Int(md[2i+1] + 1 - pointer(str))
    ix1, prevind(str, ix1 + Int(md[2i+2]))
end 

function substr(str::Union{String,SubString{String}}, md::Vector{Ptr{Cvoid}}, i::Int)
    SubString(str, substrind(str, md, i)...)
end

function substrr(str::Union{String,SubString{String}}, md::Vector{Ptr{Cvoid}}, i::Int)
    colon(substrind(str, md, i)...)
end

"""
    matchall(r::Regex2, s::AbstractString; overlap::Bool = false]) -> Vector{AbstractString}

Return a vector of the matching substrings from [`eachmatch`](@ref).


# Examples
```jldoctest
julia> rx = r"a.a"
r"a.a"

julia> matchall(rx, "a1a2a3a")
2-element Array{SubString{String},1}:
 "a1a"
 "a3a"

julia> matchall(rx, "a1a2a3a", overlap = true)
3-element Array{SubString{String},1}:
 "a1a"
 "a2a"
 "a3a"
```
"""
function matchall(re::Regex2, str::String; overlap::Bool = false)
    regex = compile(re).regex
    regex2 = regex
    copts = re.compile_options
    longmatch = copts & LONGEST_MATCH != 0            
    need2 = !longmatch
    n = nextind(str, lastindex(str))
    offset = Cuint(firstindex(str))
    opts = get_match_options(re)
    opts2 = get_match_options(ANCHORED|re.match_options)
    matches = SubString{String}[]

    while offset <= n && CRE2.exec(regex, str, offset-1, opts, re.match_data, 1)
        ix1, ix2 = substrind(str, re.match_data, 0)
        push!(matches, SubString(str, ix1, ix2))

        if ix1 > ix2 && !longmatch
            if need2
                regex2 = Regex2(re.pattern, copts|LONGEST_MATCH, re.match_options).regex
                need2 = false
            end
            if CRE2.exec(regex2, str, offset-1, opts2, re.match_data, 1)
                ix1, ix2 = substrind(str, re.match_data, 0)
                if ix1 <= ix2
                    push!(matches, SubString(str, ix1, ix2))
                end
            end
        end
        offset == n && break
        offset = Cuint(overlap ? nextind(str, ix1) : nextind(str, max(ix1, ix2)))
    end
    matches
end

matchall(re::Regex2, str::SubString; overlap::Bool = false) =
    matchall(re, String(str), overlap = overlap)

# TODO: return only start index and update deprecation
function findnext(re::Regex2, str::Union{String,SubString}, idx::Integer)
    if idx > nextind(str,lastindex(str))
        throw(BoundsError())
    end
    opts = get_match_options(re.match_options)
    compile(re)
    md = re.match_data
    CRE2.exec(re.regex, str, idx-1, opts, re.match_data) ? substrr(str, md, 0) : (0:-1)
end
findnext(r::Regex2, s::AbstractString, idx::Integer) = throw(ArgumentError(
    "regex search is only available for the String type; use String(s) to convert"
))
findfirst(r::Regex2, s::AbstractString) = findnext(r,s,firstindex(s))

replace_err(repl) = error("Bad replacement string: $repl")

function _write_capture(io, re::Regex2, group)
    len = CRE2.substring_length_bynumber(re.match_data, group)
    ensureroom(io, len+1)
    CRE2.substring_copy_bynumber(re.match_data, group,
        pointer(io.data, io.ptr), len+1)
    io.ptr += len
    io.size = max(io.size, io.ptr - 1)
end

function Base._replace(io, repl_s::SubstitutionString, str, r, re::Regex2)
    SUB_CHAR = '\\'
    GROUP_CHAR = 'g'
    LBRACKET = '<'
    RBRACKET = '>'
    repl = repl_s.string
    i = firstindex(repl)
    e = lastindex(repl)
    while i <= e
        if repl[i] == SUB_CHAR
            next_i = nextind(repl, i)
            next_i > e && replace_err(repl)
            if repl[next_i] == SUB_CHAR
                write(io, SUB_CHAR)
                i = nextind(repl, next_i)
            elseif isdigit(repl[next_i])
                group = parse(Int, repl[next_i])
                i = nextind(repl, next_i)
                while i <= e
                    if isdigit(repl[i])
                        group = 10group + parse(Int, repl[i])
                        i = nextind(repl, i)
                    else
                        break
                    end
                end
                _write_capture(io, re, group)
            elseif repl[next_i] == GROUP_CHAR
                i = nextind(repl, next_i)
                if i > e || repl[i] != LBRACKET
                    replace_err(repl)
                end
                i = nextind(repl, i)
                i > e && replace_err(repl)
                groupstart = i
                while repl[i] != RBRACKET
                    i = nextind(repl, i)
                    i > e && replace_err(repl)
                end
                #  TODO: avoid this allocation
                groupname = SubString(repl, groupstart, prevind(repl, i))
                if all(isdigit, groupname)
                    _write_capture(io, re, parse(Int, groupname))
                else
                    group = CRE2.group_number_from_name(re.regex, groupname)
                    group < 0 && replace_err("Group $groupname not found in regex $re")
                    _write_capture(io, re, group)
                end
                i = nextind(repl, i)
            else
                replace_err(repl)
            end
        else
            write(io, repl[i])
            i = nextind(repl, i)
        end
    end
end

mutable struct Regex2MatchIterator
    regex::Regex2
    string::String
    overlap::Bool
    regex2::Regex2
    longmatch::Bool

    function Regex2MatchIterator(regex::Regex2, string::AbstractString, ovr::Bool=false)
        new(regex, string, ovr, regex, regex.compile_options & LONGEST_MATCH != 0)
    end
end
compile(itr::Regex2MatchIterator) = (compile(itr.regex); itr)
eltype(::Type{Regex2MatchIterator}) = Regex2Match
start(itr::Regex2MatchIterator) = match(itr.regex, itr.string, 1, UInt32(0))
done(itr::Regex2MatchIterator, prev_match) = (prev_match === nothing)
IteratorSize(::Type{Regex2MatchIterator}) = SizeUnknown()

# Assumes prev_match is not nothing
function next(itr::Regex2MatchIterator, prev_match)
    prevempty = isempty(prev_match.match)

    if itr.overlap
        if !prevempty
            offset = nextind(itr.string, prev_match.offset)
        else
            offset = prev_match.offset
        end
    else
        offset = prev_match.offset + lastindex(prev_match.match)
    end
   
    regex = itr.regex
    if !itr.longmatch && prevempty
        if regex === itr.regex2
            itr.regex2 = Regex2(regex.pattern, regex.compile_options|LONGEST_MATCH, 0)
        end
        mat = match(itr.regex2, itr.string, offset, ANCHORED)
        if mat !== nothing && !isempty(mat.match)
            return (prev_match, mat)
        elseif offset > sizeof(itr.string)
            return (prev_match, nothing)
        end
    end

    offset = nextind(itr.string, min(offset, lastindex(itr.string))) 
    mat = match(regex, itr.string, offset, UInt32(0))
    if mat != nothing && isempty(mat.match) &&
        offset == prev_match.offset > lastindex(itr.string)

        mat = nothing
    end
    return (prev_match, mat)
end

"""
    eachmatch(r::Regex2, s::AbstractString; overlap::Bool=false])

Search for all matches of a the regular expression `r` in `s` and return a iterator over the
matches. If overlap is `true`, the matching sequences are allowed to overlap indices in the
original string, otherwise they must be from distinct character ranges.

# Examples
```jldoctest
julia> rx = rr"a.a"
r"a.a"

julia> m = eachmatch(rx, "a1a2a3a")
Base.Regex2MatchIterator(r"a.a", "a1a2a3a", false)

julia> collect(m)
2-element Array{Regex2Match,1}:
 Regex2Match("a1a")
 Regex2Match("a3a")

julia> collect(eachmatch(rx, "a1a2a3a", overlap = true))
3-element Array{Regex2Match,1}:
 Regex2Match("a1a")
 Regex2Match("a2a")
 Regex2Match("a3a")
```
"""
eachmatch(re::Regex2, str::AbstractString; overlap = false) =
    Regex2MatchIterator(re, str, overlap)

## comparison ##

function ==(a::Regex2, b::Regex2)
    a.pattern == b.pattern && a.compile_options == b.compile_options && a.match_options == b.match_options
end

## hash ##
const hashre_seed = UInt === UInt64 ? 0x67e195eb8555e72d : 0xe32373e4
function hash(r::Regex2, h::UInt)
    h += hashre_seed
    h = hash(r.pattern, h)
    h = hash(r.compile_options, h)
    h = hash(r.match_options, h)
end

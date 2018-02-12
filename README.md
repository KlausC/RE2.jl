# RE2

[![Build Status](https://travis-ci.org/KlausC/RE2.jl.svg?branch=master)](https://travis-ci.org/KlausC/RE2.jl)
[![Coverage Status](https://coveralls.io/repos/KlausC/RE2.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/KlausC/RE2.jl?branch=master)
[![codecov.io](http://codecov.io/github/KlausC/RE2.jl/coverage.svg?branch=master)](http://codecov.io/github/KlausC/RE2.jl?branch=master)


Wrapper to the RE2 regular expression implementation.

Special feature (compared to PCRE), the "l" compilation flag for "longest match".

See [RE2](https://github.com/google/re2). Using the C-interface
[CRE2](https://github.com/marcomaggi/cre2)

### Installtion:

Requires the libraries libcre2 and libre2 installed in the standard library path.

### Usage

```
julia> using RE2

julia> re = rr"x*|y*"l
rr"x*|y*"l

julia> match(re, "yyayyx")
Regex2Match("yy")

julia> match(r"x*|y*", "yyayyx")
RegexMatch("")
```



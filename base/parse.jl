# This file is a part of Julia. License is MIT: https://julialang.org/license

import Base.Checked: add_with_overflow, mul_with_overflow

## string to integer functions ##

"""
    parse(type, str; base)

Parse a string as a number. For `Integer` types, a base can be specified
(the default is 10). For floating-point types, the string is parsed as a decimal
floating-point number.  `Complex` types are parsed from decimal strings
of the form `"R±Iim"` as a `Complex(R,I)` of the requested type; `"i"` or `"j"` can also be
used instead of `"im"`, and `"R"` or `"Iim"` are also permitted.
If the string does not contain a valid number, an error is raised.

```jldoctest
julia> parse(Int, "1234")
1234

julia> parse(Int, "1234", base = 5)
194

julia> parse(Int, "afc", base = 16)
2812

julia> parse(Float64, "1.2e-3")
0.0012

julia> parse(Complex{Float64}, "3.2e-1 + 4.5im")
0.32 + 4.5im
```
"""
parse(T::Type, str; base = Int)

function parse(::Type{T}, c::Char; base::Integer = 36) where T<:Integer
    a::Int = (base <= 36 ? 10 : 36)
    2 <= base <= 62 || throw(ArgumentError("invalid base: base must be 2 ≤ base ≤ 62, got $base"))
    d = '0' <= c <= '9' ? c-'0'    :
        'A' <= c <= 'Z' ? c-'A'+10 :
        'a' <= c <= 'z' ? c-'a'+a  : throw(ArgumentError("invalid digit: $(repr(c))"))
    d < base || throw(ArgumentError("invalid base $base digit $(repr(c))"))
    convert(T, d)
end

function parseint_next(s::AbstractString, startpos::Int, endpos::Int)
    (0 < startpos <= endpos) || (return Char(0), 0, 0)
    j = startpos
    c, startpos = next(s,startpos)
    c, startpos, j
end

function parseint_preamble(signed::Bool, base::Int, s::AbstractString, startpos::Int, endpos::Int)
    c, i, j = parseint_next(s, startpos, endpos)

    while isspace(c)
        c, i, j = parseint_next(s,i,endpos)
    end
    (j == 0) && (return 0, 0, 0)

    sgn = 1
    if signed
        if c == '-' || c == '+'
            (c == '-') && (sgn = -1)
            c, i, j = parseint_next(s,i,endpos)
        end
    end

    while isspace(c)
        c, i, j = parseint_next(s,i,endpos)
    end
    (j == 0) && (return 0, 0, 0)

    if base == 0
        if c == '0' && !done(s,i)
            c, i = next(s,i)
            base = c=='b' ? 2 : c=='o' ? 8 : c=='x' ? 16 : 10
            if base != 10
                c, i, j = parseint_next(s,i,endpos)
            end
        else
            base = 10
        end
    end
    return sgn, base, j
end

function tryparse_internal(::Type{T}, s::AbstractString, startpos::Int, endpos::Int, base_::Integer, raise::Bool) where T<:Integer
    sgn, base, i = parseint_preamble(T<:Signed, Int(base_), s, startpos, endpos)
    if sgn == 0 && base == 0 && i == 0
        raise && throw(ArgumentError("input string is empty or only contains whitespace"))
        return nothing
    end
    if !(2 <= base <= 62)
        raise && throw(ArgumentError("invalid base: base must be 2 ≤ base ≤ 62, got $base"))
        return nothing
    end
    if i == 0
        raise && throw(ArgumentError("premature end of integer: $(repr(SubString(s,startpos,endpos)))"))
        return nothing
    end
    c, i = parseint_next(s,i,endpos)
    if i == 0
        raise && throw(ArgumentError("premature end of integer: $(repr(SubString(s,startpos,endpos)))"))
        return nothing
    end

    base = convert(T,base)
    m::T = div(typemax(T)-base+1,base)
    n::T = 0
    a::Int = base <= 36 ? 10 : 36
    while n <= m
        d::T = '0' <= c <= '9' ? c-'0'    :
               'A' <= c <= 'Z' ? c-'A'+10 :
               'a' <= c <= 'z' ? c-'a'+a  : base
        if d >= base
            raise && throw(ArgumentError("invalid base $base digit $(repr(c)) in $(repr(SubString(s,startpos,endpos)))"))
            return nothing
        end
        n *= base
        n += d
        if i > endpos
            n *= sgn
            return n
        end
        c, i = next(s,i)
        isspace(c) && break
    end
    (T <: Signed) && (n *= sgn)
    while !isspace(c)
        d::T = '0' <= c <= '9' ? c-'0'    :
        'A' <= c <= 'Z' ? c-'A'+10 :
            'a' <= c <= 'z' ? c-'a'+a  : base
        if d >= base
            raise && throw(ArgumentError("invalid base $base digit $(repr(c)) in $(repr(SubString(s,startpos,endpos)))"))
            return nothing
        end
        (T <: Signed) && (d *= sgn)

        n, ov_mul = mul_with_overflow(n, base)
        n, ov_add = add_with_overflow(n, d)
        if ov_mul | ov_add
            raise && throw(OverflowError("overflow parsing $(repr(SubString(s,startpos,endpos)))"))
            return nothing
        end
        (i > endpos) && return n
        c, i = next(s,i)
    end
    while i <= endpos
        c, i = next(s,i)
        if !isspace(c)
            raise && throw(ArgumentError("extra characters after whitespace in $(repr(SubString(s,startpos,endpos)))"))
            return nothing
        end
    end
    return n
end

function tryparse_internal(::Type{Bool}, sbuff::Union{String,SubString{String}},
        startpos::Int, endpos::Int, base::Integer, raise::Bool)
    if isempty(sbuff)
        raise && throw(ArgumentError("input string is empty"))
        return nothing
    end

    orig_start = startpos
    orig_end   = endpos

    # Ignore leading and trailing whitespace
    while isspace(sbuff[startpos]) && startpos <= endpos
        startpos = nextind(sbuff, startpos)
    end
    while isspace(sbuff[endpos]) && endpos >= startpos
        endpos = prevind(sbuff, endpos)
    end

    len = endpos - startpos + 1
    p   = pointer(sbuff) + startpos - 1
    GC.@preserve sbuff begin
        (len == 4) && (0 == ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, UInt),
                                  p, "true", 4)) && (return true)
        (len == 5) && (0 == ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, UInt),
                                  p, "false", 5)) && (return false)
    end

    if raise
        substr = SubString(sbuff, orig_start, orig_end) # show input string in the error to avoid confusion
        if all(isspace, substr)
            throw(ArgumentError("input string only contains whitespace"))
        else
            throw(ArgumentError("invalid Bool representation: $(repr(substr))"))
        end
    end
    return nothing
end

@inline function check_valid_base(base)
    if 2 <= base <= 62
        return base
    end
    throw(ArgumentError("invalid base: base must be 2 ≤ base ≤ 62, got $base"))
end

"""
    tryparse(type, str; base)

Like [`parse`](@ref), but returns either a value of the requested type,
or [`nothing`](@ref) if the string does not contain a valid number.
"""
function tryparse(::Type{T}, s::AbstractString; base::Union{Nothing,Integer} = nothing) where {T<:Integer}
    # Zero base means, "figure it out"
    tryparse_internal(T, s, start(s), lastindex(s), base===nothing ? 0 : check_valid_base(base), false)
end

function parse(::Type{T}, s::AbstractString; base::Union{Nothing,Integer} = nothing) where {T<:Integer}
    tryparse_internal(T, s, start(s), lastindex(s), base===nothing ? 0 : check_valid_base(base), true)
end

## string to float functions ##
function parsefloat_preamble(s::AbstractString, base::Int, i::Int=1)
    isempty(s) && throw(ArgumentError("Empty string!"))
    c = ' '
    sign = 1
    while isspace(c)
        c, i = next(s,i)
    end
    if c in ('-', '+')
        sign = (c == '-') ? -1 : 1
        c, i = next(s, i)
    end
    while isspace(c)
        c, i = next(s,i)
    end
    startpos = i-1
    return sign, startpos
end

function parse{T<:AbstractFloat}(::Type{T}, s::AbstractString, base::Integer)
    sign, i = parsefloat_preamble(s, base)

    if !done(s, i+2)
        nan = [false, false, false]
        inf = [false, false, false]
        for j in 1:3
            c, _ = next(s, i+j-1)
            nan[j] = lowercase(c) == "nan"[j]
            inf[j] = lowercase(c) == "inf"[j]
        end
        all(nan) && return T(NaN)
        all(inf) && return sign*T(Inf)
    end

    baseunder15 = base < 15 # only interpret 'e' as scientific notation if unambiguous
    b = T(base)
    res = zero(T)
    while !done(s, i)
        c, i = next(s, i)
        isspace(c) && break
        c == '.' && break
        if baseunder15 && c == 'e'
            i -= 1
            break
        end
        tmp = parse(Int, c, base=base)

        res = res * b + tmp
    end

    n = 0
    while !done(s, i)
        n -= 1
        c, i = next(s, i)
        isspace(c) && break
        baseunder15 && c == 'e' && break
        tmp = parse(Int, c, base=base)

        res += tmp * b^n
    end

    expsign = 1
    exponent = 0
    while baseunder15 && !done(s, i)
        c, i = next(s, i)
        isspace(c) && break
        if c == '-'
            expsign = -1
            continue
        end
        tmp = parse(Int, c, base=base)

        exponent = exponent * base + tmp
    end

    return sign*res*b^(expsign*exponent)
end

function tryparse(::Type{Float64}, s::String)
    hasvalue, val = ccall(:jl_try_substrtod, Tuple{Bool, Float64},
                          (Ptr{UInt8},Csize_t,Csize_t), s, 0, sizeof(s))
    hasvalue ? val : nothing
end
function tryparse(::Type{Float64}, s::SubString{String})
    hasvalue, val = ccall(:jl_try_substrtod, Tuple{Bool, Float64},
                          (Ptr{UInt8},Csize_t,Csize_t), s.string, s.offset, s.ncodeunits)
    hasvalue ? val : nothing
end
function tryparse_internal(::Type{Float64}, s::String, startpos::Int, endpos::Int)
    hasvalue, val = ccall(:jl_try_substrtod, Tuple{Bool, Float64},
                          (Ptr{UInt8},Csize_t,Csize_t), s, startpos-1, endpos-startpos+1)
    hasvalue ? val : nothing
end
function tryparse_internal(::Type{Float64}, s::SubString{String}, startpos::Int, endpos::Int)
    hasvalue, val = ccall(:jl_try_substrtod, Tuple{Bool, Float64},
                          (Ptr{UInt8},Csize_t,Csize_t), s.string, s.offset+startpos-1, endpos-startpos+1)
    hasvalue ? val : nothing
end
function tryparse(::Type{Float32}, s::String)
    hasvalue, val = ccall(:jl_try_substrtof, Tuple{Bool, Float32},
                          (Ptr{UInt8},Csize_t,Csize_t), s, 0, sizeof(s))
    hasvalue ? val : nothing
end
function tryparse(::Type{Float32}, s::SubString{String})
    hasvalue, val = ccall(:jl_try_substrtof, Tuple{Bool, Float32},
                          (Ptr{UInt8},Csize_t,Csize_t), s.string, s.offset, s.ncodeunits)
    hasvalue ? val : nothing
end
function tryparse_internal(::Type{Float32}, s::String, startpos::Int, endpos::Int)
    hasvalue, val = ccall(:jl_try_substrtof, Tuple{Bool, Float32},
                          (Ptr{UInt8},Csize_t,Csize_t), s, startpos-1, endpos-startpos+1)
    hasvalue ? val : nothing
end
function tryparse_internal(::Type{Float32}, s::SubString{String}, startpos::Int, endpos::Int)
    hasvalue, val = ccall(:jl_try_substrtof, Tuple{Bool, Float32},
                          (Ptr{UInt8},Csize_t,Csize_t), s.string, s.offset+startpos-1, endpos-startpos+1)
    hasvalue ? val : nothing
end
tryparse(::Type{T}, s::AbstractString) where {T<:Union{Float32,Float64}} = tryparse(T, String(s))
tryparse(::Type{Float16}, s::AbstractString) =
    convert(Union{Float16, Nothing}, tryparse(Float32, s))
tryparse_internal(::Type{Float16}, s::AbstractString, startpos::Int, endpos::Int) =
    convert(Union{Float16, Nothing}, tryparse_internal(Float32, s, startpos, endpos))

## string to complex functions ##

function tryparse_internal(::Type{Complex{T}}, s::Union{String,SubString{String}}, i::Int, e::Int, raise::Bool) where {T<:Real}
    # skip initial whitespace
    while i ≤ e && isspace(s[i])
        i = nextind(s, i)
    end
    if i > e
        raise && throw(ArgumentError("input string is empty or only contains whitespace"))
        return nothing
    end

    # find index of ± separating real/imaginary parts (if any)
    i₊ = coalesce(findnext(occursin(('+','-')), s, i), 0)
    if i₊ == i # leading ± sign
        i₊ = coalesce(findnext(occursin(('+','-')), s, i₊+1), 0)
    end
    if i₊ != 0 && s[i₊-1] in ('e','E') # exponent sign
        i₊ = coalesce(findnext(occursin(('+','-')), s, i₊+1), 0)
    end

    # find trailing im/i/j
    iᵢ = coalesce(findprev(occursin(('m','i','j')), s, e), 0)
    if iᵢ > 0 && s[iᵢ] == 'm' # im
        iᵢ -= 1
        if s[iᵢ] != 'i'
            raise && throw(ArgumentError("expected trailing \"im\", found only \"m\""))
            return nothing
        end
    end

    if i₊ == 0 # purely real or imaginary value
        if iᵢ > 0 # purely imaginary
            x = tryparse_internal(T, s, i, iᵢ-1, raise)
            x === nothing && return nothing
            return Complex{T}(zero(x),x)
        else # purely real
            return Complex{T}(tryparse_internal(T, s, i, e, raise))
        end
    end

    if iᵢ < i₊
        raise && throw(ArgumentError("missing imaginary unit"))
        return nothing # no imaginary part
    end

    # parse real part
    re = tryparse_internal(T, s, i, i₊-1, raise)
    re === nothing && return nothing

    # parse imaginary part
    im = tryparse_internal(T, s, i₊+1, iᵢ-1, raise)
    im === nothing && return nothing

    return Complex{T}(re, s[i₊]=='-' ? -im : im)
end

# the ±1 indexing above for ascii chars is specific to String, so convert:
tryparse_internal(T::Type{<:Complex}, s::AbstractString, i::Int, e::Int, raise::Bool) =
    tryparse_internal(T, String(s), i, e, raise)

# fallback methods for tryparse_internal
tryparse_internal(::Type{T}, s::AbstractString, startpos::Int, endpos::Int) where T<:Real =
    startpos == start(s) && endpos == lastindex(s) ? tryparse(T, s) : tryparse(T, SubString(s, startpos, endpos))
function tryparse_internal(::Type{T}, s::AbstractString, startpos::Int, endpos::Int, raise::Bool) where T<:Real
    result = tryparse_internal(T, s, startpos, endpos)
    if raise && result === nothing
        throw(ArgumentError("cannot parse $(repr(s[startpos:endpos])) as $T"))
    end
    return result
end
tryparse_internal(::Type{T}, s::AbstractString, startpos::Int, endpos::Int, raise::Bool) where T<:Integer =
    tryparse_internal(T, s, startpos, endpos, 10, raise)

parse(::Type{T}, s::AbstractString) where T<:Union{Real,Complex} =
    tryparse_internal(T, s, start(s), lastindex(s), true)

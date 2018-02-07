# This file is a part of Julia. License is MIT: https://julialang.org/license

# integer parsing
@test parse(Int32,"0", base = 36) === Int32(0)
@test parse(Int32,"1", base = 36) === Int32(1)
@test parse(Int32,"9", base = 36) === Int32(9)
@test parse(Int32,"A", base = 36) === Int32(10)
@test parse(Int32,"a", base = 36) === Int32(10)
@test parse(Int32,"B", base = 36) === Int32(11)
@test parse(Int32,"b", base = 36) === Int32(11)
@test parse(Int32,"F", base = 36) === Int32(15)
@test parse(Int32,"f", base = 36) === Int32(15)
@test parse(Int32,"Z", base = 36) === Int32(35)
@test parse(Int32,"z", base = 36) === Int32(35)

@test parse(Int,"0") == 0
@test parse(Int,"-0") == 0
@test parse(Int,"1") == 1
@test parse(Int,"-1") == -1
@test parse(Int,"9") == 9
@test parse(Int,"-9") == -9
@test parse(Int,"10") == 10
@test parse(Int,"-10") == -10
@test parse(Int64,"3830974272") == 3830974272
@test parse(Int64,"-3830974272") == -3830974272
@test parse(Int,'3') == 3
@test parse(Int,'3', base = 8) == 3

# Issue 20587
for T in Any[BigInt, Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8]
    T === BigInt && continue # TODO: make BigInt pass this test
    for s in ["", " ", "  "]
        # Without a base (handles things like "0x00001111", etc)
        result = @test_throws ArgumentError parse(T, s)
        exception_without_base = result.value
        if T == Bool
            if s == ""
                @test exception_without_base.msg == "input string is empty"
            else
                @test exception_without_base.msg == "input string only contains whitespace"
            end
        else
            @test exception_without_base.msg == "input string is empty or only contains whitespace"
        end

        # With a base
        result = @test_throws ArgumentError parse(T, s, base = 16)
        exception_with_base = result.value
        if T == Bool
            if s == ""
                @test exception_with_base.msg == "input string is empty"
            else
                @test exception_with_base.msg == "input string only contains whitespace"
            end
        else
            @test exception_with_base.msg == "input string is empty or only contains whitespace"
        end
    end

    # Test `tryparse_internal` with part of a string
    let b = "                   "
        result = @test_throws ArgumentError Base.tryparse_internal(Bool, b, 7, 11, 0, true)
        exception_bool = result.value
        @test exception_bool.msg == "input string only contains whitespace"

        result = @test_throws ArgumentError Base.tryparse_internal(Int, b, 7, 11, 0, true)
        exception_int = result.value
        @test exception_int.msg == "input string is empty or only contains whitespace"

        result = @test_throws ArgumentError Base.tryparse_internal(UInt128, b, 7, 11, 0, true)
        exception_uint = result.value
        @test exception_uint.msg == "input string is empty or only contains whitespace"
    end

    # Test that the entire input string appears in error messages
    let s = "     false    true     "
        result = @test_throws(ArgumentError,
            Base.tryparse_internal(Bool, s, firstindex(s), lastindex(s), 0, true))
        @test result.value.msg == "invalid Bool representation: $(repr(s))"
    end

    # Test that leading and trailing whitespace is ignored.
    for v in (1, 2, 3)
        @test parse(Int, "    $v"    ) == v
        @test parse(Int, "    $v\n"  ) == v
        @test parse(Int, "$v    "    ) == v
        @test parse(Int, "    $v    ") == v
    end
    for v in (true, false)
        @test parse(Bool, "    $v"    ) == v
        @test parse(Bool, "    $v\n"  ) == v
        @test parse(Bool, "$v    "    ) == v
        @test parse(Bool, "    $v    ") == v
    end
    for v in (0.05, -0.05, 2.5, -2.5)
        @test parse(Float64, "    $v"    ) == v
        @test parse(Float64, "    $v\n"  ) == v
        @test parse(Float64, "$v    "    ) == v
        @test parse(Float64, "    $v    ") == v
    end
    @test parse(Float64, "    .5"    ) == 0.5
    @test parse(Float64, "    .5\n"  ) == 0.5
    @test parse(Float64, "    .5    ") == 0.5
    @test parse(Float64, ".5    "    ) == 0.5
end

@test parse(Bool, "\u202f true") === true
@test parse(Bool, "\u202f false") === false

parsebin(s) = parse(Int,s, base = 2)
parseoct(s) = parse(Int,s, base = 8)
parsehex(s) = parse(Int,s, base = 16)

@test parsebin("0") == 0
@test parsebin("-0") == 0
@test parsebin("1") == 1
@test parsebin("-1") == -1
@test parsebin("10") == 2
@test parsebin("-10") == -2
@test parsebin("11") == 3
@test parsebin("-11") == -3
@test parsebin("1111000011110000111100001111") == 252645135
@test parsebin("-1111000011110000111100001111") == -252645135

@test parseoct("0") == 0
@test parseoct("-0") == 0
@test parseoct("1") == 1
@test parseoct("-1") == -1
@test parseoct("7") == 7
@test parseoct("-7") == -7
@test parseoct("10") == 8
@test parseoct("-10") == -8
@test parseoct("11") == 9
@test parseoct("-11") == -9
@test parseoct("72") == 58
@test parseoct("-72") == -58
@test parseoct("3172207320") == 434704080
@test parseoct("-3172207320") == -434704080

@test parsehex("0") == 0
@test parsehex("-0") == 0
@test parsehex("1") == 1
@test parsehex("-1") == -1
@test parsehex("9") == 9
@test parsehex("-9") == -9
@test parsehex("a") == 10
@test parsehex("-a") == -10
@test parsehex("f") == 15
@test parsehex("-f") == -15
@test parsehex("10") == 16
@test parsehex("-10") == -16
@test parsehex("0BADF00D") == 195948557
@test parsehex("-0BADF00D") == -195948557
@test parse(Int64,"BADCAB1E", base = 16) == 3135023902
@test parse(Int64,"-BADCAB1E", base = 16) == -3135023902
@test parse(Int64,"CafeBabe", base = 16) == 3405691582
@test parse(Int64,"-CafeBabe", base = 16) == -3405691582
@test parse(Int64,"DeadBeef", base = 16) == 3735928559
@test parse(Int64,"-DeadBeef", base = 16) == -3735928559

@test parse(Int,"2\n") == 2
@test parse(Int,"   2 \n ") == 2
@test parse(Int," 2 ") == 2
@test parse(Int,"2 ") == 2
@test parse(Int," 2") == 2
@test parse(Int,"+2\n") == 2
@test parse(Int,"-2") == -2
@test_throws ArgumentError parse(Int,"   2 \n 0")
@test_throws ArgumentError parse(Int,"2x")
@test_throws ArgumentError parse(Int,"-")

# multibyte spaces
@test parse(Int, "3\u2003\u202F") == 3
@test_throws ArgumentError parse(Int, "3\u2003\u202F,")

@test parse(Int,'a') == 10
@test_throws ArgumentError parse(Int,typemax(Char))

@test parse(Int,"1234") == 1234
@test parse(Int,"0x1234") == 0x1234
@test parse(Int,"0o1234") == 0o1234
@test parse(Int,"0b1011") == 0b1011
@test parse(Int,"-1234") == -1234
@test parse(Int,"-0x1234") == -Int(0x1234)
@test parse(Int,"-0o1234") == -Int(0o1234)
@test parse(Int,"-0b1011") == -Int(0b1011)

for T in (Int8, Int16, Int32, Int64, Int128)
    @test parse(T,string(typemin(T))) == typemin(T)
    @test parse(T,string(typemax(T))) == typemax(T)
    @test_throws OverflowError parse(T,string(big(typemin(T))-1))
    @test_throws OverflowError parse(T,string(big(typemax(T))+1))
end

for T in (UInt8,UInt16,UInt32,UInt64,UInt128)
    @test parse(T,string(typemin(T))) == typemin(T)
    @test parse(T,string(typemax(T))) == typemax(T)
    @test_throws ArgumentError parse(T,string(big(typemin(T))-1))
    @test_throws OverflowError parse(T,string(big(typemax(T))+1))
end

# issue #15597
# make sure base can be any Integer
for T in (Int, BigInt)
    let n = parse(T, "123", base = Int8(10))
        @test n == 123
        @test isa(n, T)
    end
end

# issue #17065
@test parse(Int, "2") === 2
@test parse(Bool, "true") === true
@test parse(Bool, "false") === false
@test tryparse(Bool, "true") === true
@test tryparse(Bool, "false") === false
@test_throws ArgumentError parse(Int, "2", base = 1)
@test_throws ArgumentError parse(Int, "2", base = 63)

# issue #17333: tryparse should still throw on invalid base
for T in (Int32, BigInt), base in (0,1,100)
    @test_throws ArgumentError tryparse(T, "0", base = base)
end

# error throwing branch from #10560
@test_throws ArgumentError Base.tryparse_internal(Bool, "foo", 1, 2, 10, true)

@test tryparse(Float64, "1.23") === 1.23
@test tryparse(Float32, "1.23") === 1.23f0
@test tryparse(Float16, "1.23") === Float16(1.23)

# parsing complex numbers (#22250)
@testset "complex parsing" begin
    for r in (1,0,-1), i in (1,0,-1), sign in ('-','+'), Im in ("i","j","im")
        for s1 in (""," "), s2 in (""," "), s3 in (""," "), s4 in (""," ")
            n = Complex(r, sign == '+' ? i : -i)
            s = string(s1, r, s2, sign, s3, i, Im, s4)
            @test n === parse(Complex{Int}, s)
            @test Complex(r) === parse(Complex{Int}, string(s1, r, s2))
            @test Complex(0,i) === parse(Complex{Int}, string(s3, i, Im, s4))
            for T in (Float64, BigFloat)
                nT = parse(Complex{T}, s)
                @test nT isa Complex{T}
                @test nT == n
                @test n == parse(Complex{T}, string(s1, r, ".0", s2, sign, s3, i, ".0", Im, s4))
                @test n*parse(T,"1e-3") == parse(Complex{T}, string(s1, r, "e-3", s2, sign, s3, i, "e-3", Im, s4))
            end
        end
    end
    @test parse(Complex{Float16}, "3.3+4i") === Complex{Float16}(3.3+4im)
    @test parse(Complex{Int}, SubString("xxxxxx1+2imxxxx", 7, 10)) === 1+2im
    for T in (Int, Float64), bad in ("3 + 4*im", "3 + 4", "1+2ij", "1im-3im", "++4im")
        @test_throws ArgumentError parse(Complex{T}, bad)
    end
    @test_throws ArgumentError parse(Complex{Int}, "3 + 4.2im")
end

# added ⟂ to operator precedence (#24404)
@test Meta.parse("a ⟂ b ⟂ c") == Expr(:comparison, :a, :⟂, :b, :⟂, :c)
@test Meta.parse("a ⟂ b ∥ c") == Expr(:comparison, :a, :⟂, :b, :∥, :c)

# only allow certain characters after interpolated vars (#25231)
@test Meta.parse("\"\$x෴  \"",raise=false) == Expr(:error, "interpolated variable \$x ends with invalid character \"෴\"; use \"\$(x)\" instead.")
@test Base.incomplete_tag(Meta.parse("\"\$foo", raise=false)) == :string

# issue #22480
@test isnan(parse(Float64, "NaN", base=16))
@test isnan(parse(Float64, "nan", base=16))
@test isnan(parse(Float64, "nAN", base=16))

@test parse(Float64, "Inf", base=16) === Inf
@test parse(Float64, "+Inf", base=16) === Inf
@test parse(Float64, "-Inf", base=16) === -Inf
@test parse(Float64, "inf", base=16) === Inf
@test parse(Float64, "inf ", base=16) === Inf

@test parse(Float32, "100.1", base=2) === 4.5f0
@test parse(Float32, "100.1  ", base=2) === 4.5f0
@test parse(Float32, "+100.1", base=2) === 4.5f0
@test parse(Float32, "-100.1", base=2) === -4.5f0

@test parse(Float64, "ff.4", base=16) === 255.25
@test parse(Float64, "+FF.4", base=16) === 255.25
@test parse(Float64, "+ff.4  ", base=16) === 255.25
@test parse(Float64, "  -ff.4", base=16) === -255.25
@test parse(Float64, "1.1", base=2) === 1.5
@test parse(Float64, "0.001", base=2) === 0.125
@test parse(Float64, "100", base=2) === 4.0
@test parse(Float64, "+100", base=2) === 4.0
@test parse(Float64, "100 ", base=2) === 4.0
@test parse(Float64, "100\t", base=2) === 4.0
@test parse(Float64, "\t100", base=2) === 4.0
@test parse(Float64, "-100.0", base=2) === -4.0
@test parse(Float64, "0.1", base=3) === 0.3333333333333333

@test parse(Float64, "2.3e3", base=4) === 176.0
@test parse(Float64, "2.3e-3", base=4) === 0.04296875
@test_throws ArgumentError parse(Float64, "2.3e4", base=4)
@test parse(Float64, "2.3e10", base=4) === 704.0
@test parse(Float64, "2.3e4", base=5) === 1625.0
@test parse(Float64, "2.3e23", base=5) === 3.173828125e9
@test parse(Float64, "2.3e-23", base=5) === 2.12992e-9
@test parse(Float64, "1e3", base=5) === 125.0
@test_throws ArgumentError parse(Float64, "1e6", base=5)
@test parse(Float64, "1e6", base=10) === 1000000.0

@test parse(BigFloat, "2.3e-23", base=5) == big"2.129919999999999999999999999999999999999999999999999999999999999999999999999986e-09"

@test_throws ArgumentError parse(Float64, "1.2e2 some nonesense", base=10)
@test_throws ArgumentError parse(Float64, "1 .2e2", base=10)
@test_throws ArgumentError parse(Float64, "1. 2e2", base=10)
@test_throws ArgumentError parse(Float64, "1.2 e2", base=10)
@test_throws ArgumentError parse(Float64, "1.2e 2", base=10)
@test_throws ArgumentError parse(Float64, "nanana", base=10)

@test parse(Float64, "1e3", base=16) === Float64(16^2 + 14*16^1 + 3*16^0)
@test parse(Float64, "1e3", base=10)  === 1000.0
@test parse(Float64, "1E3", base=10)  === 1000.0

@test_throws ArgumentError parse(Float64, "14.0", base=3)

@testset "parse and tryparse type inference" begin
    @inferred parse(Int, "12")
    @inferred parse(Float64, "12")
    @inferred parse(Complex{Int}, "12")
    @test eltype([parse(Int, s, 16) for s in String[]]) == Int
    @test eltype([parse(Float64, s) for s in String[]]) == Float64
    @test eltype([parse(Complex{Int}, s) for s in String[]]) == Complex{Int}
    @test eltype([tryparse(Int, s, 16) for s in String[]]) == Union{Nothing, Int}
    @test eltype([tryparse(Float64, s) for s in String[]]) == Union{Nothing, Float64}
    @test eltype([tryparse(Complex{Int}, s) for s in String[]]) == Union{Nothing, Complex{Int}}
end

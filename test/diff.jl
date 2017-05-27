using Patchwork
using Compat
using Base.Test

import Patchwork:
           Patch,
           TextNode,
           Elem,
           Overwrite,
           Insert,
           Delete,
           Reorder,
           DictDiff,
           are_equal

# p
p(x...) = Elem(:xhtml, :p, x)

# Structurally same
sameas(x, y) = false
sameas{T}(x::T, y::T) = x == y
sameas{T <: Patch}(x::T, y::T) =
    all([sameas(getfield(x, n), getfield(x, n)) for n in fieldnames(x)])
sameas(l::AbstractArray, r::AbstractArray) = all(map(sameas, l, r))

function sameas(l::Associative, r::Associative)
    if length(r) != length(r)
        return false
    end
    for (k, v) in l
        if !haskey(r, k) || !sameas(v, r[k])
            println("Mismatched dict key ", k, ": ", v, " <> ", r[k])
            return false
        end
    end
    true
end

@testset "Testing Diffs" begin
    @testset "testing are_equal" begin

        @test are_equal(1, 1) == true
        @test are_equal(1, 2) == false
        @test are_equal(1, 1.0) == true
        @test are_equal(1, 1.5) == false
        @test are_equal(:x, "x") == true
        @test are_equal("x", :x) == true
        @test are_equal(:x, :x) == true
        @test are_equal(:x, :y) == false
        a = [:x, :y]
        b = [:x, :y]
        @test are_equal(a, a) == true
        @test are_equal(a, b) == true
    end

    @testset "things that should return empty patches" begin
        e1 = p("a")
        e2 = p("b")
        a = @compat Dict(:x => 1)
        b = @compat Dict(:x => @compat Dict(:y => 1))
        @test isempty(diff(e1, e1))
        @test isempty(diff(p(e1), p(e1)))
        @test isempty(diff(e1, p("a")))
        @test isempty(diff(p(e1, e2), p(e1, e2)))
        @test isempty(diff(p(p("a"), e2), p(e1, p("b"))))
        @test isempty(diff(e1 & a, p("a") & a))
        @test isempty(diff(e1 & b, p("a") & b))
    end

    @testset "testing Overwrite" begin
        e1 = p("a")
        e2 = p("b")
        a = @compat Dict(1=>[Overwrite(TextNode("b"))])
        @test TextNode("a") == TextNode("a")
        @test sameas(diff(e1, e2), a)
    end
end

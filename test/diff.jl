using Patchwork, Patchwork.HTML5
using FactCheck
#using Match
using Base.Test

import Patchwork:
           Patch,
           Text,
           Elem,
           Overwrite,
           Insert,
           Delete,
           Reorder,
           DictDiff,
           are_equal


# Structurally same
sameas(x, y) = false
sameas{T}(x::T, y::T) = x == y
sameas{T <: Patch}(x::T, y::T) =
    all([sameas(getfield(x, n), getfield(x, n)) for n in names(x)])
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
sameas(x) = (y) -> sameas(x, y)

facts("Testing Diffs") do
    context("testing are_equal") do

        @fact are_equal(1, 1) => true
        @fact are_equal(1, 2) => false
        @fact are_equal(1, 1.0) => true
        @fact are_equal(1, 1.5) => false
        @fact are_equal(:x, "x") => true
        @fact are_equal("x", :x) => true
        @fact are_equal(:x, :x) => true
        @fact are_equal(:x, :y) => false
        a = [:x, :y]
        b = [:x, :y]
        @fact are_equal(a, a) => true
        @fact are_equal(a, b) => true
    end

    context("things that should return empty patches") do
        e1 = p("a")
        e2 = p("b")
        @fact diff(e1, e1) => isempty
        @fact diff(p(e1), p(e1)) => isempty
        @fact diff(e1, p("a")) => isempty
        @fact diff(p(e1, e2), p(e1, e2)) => isempty
        @fact diff(p(p("a"), e2), p(e1, p("b"))) => isempty
        @fact diff(e1 & [:x => 1], p("a") & [:x => 1]) => isempty
        @fact diff(e1 & [:x => [:y => 1]], p("a") & [:x => [:y => 1]]) => isempty
    end

    context("testing Overwrite") do
        e1 = p("a")
        e2 = p("b")
        @fact Text("a") => Text("a")
        @fact diff(e1, e2) => sameas([1=>[Overwrite(Text("b"))]])
        @fact diff(e1, e2) => sameas([1=>[Overwrite(Text("b"))]])
    end
end

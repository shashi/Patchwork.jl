using Patchwork
using Base.Test

import Patchwork: count, TextNode, Elem

ul(x...) = Elem(:xhtml, :ul, x)
li(x...) = Elem(:xhtml, :li, x)

@testset "Testing Nodes" begin
    @testset "testing counts" begin
        @test count(TextNode("a")) == 0
        @test count(ul()) == 0
        @test count(li("x")) == 1
        @test count(ul(li("x"))) == 2
        @test count(ul(li("x"), li("x"))) == 4
    end
end

@testset "Testing nested node creation" begin
  node = Elem(:div, TextNode("a"))
  @test count(node) == 1
end

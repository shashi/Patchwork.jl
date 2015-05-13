using Patchwork
using FactCheck

import Patchwork: count, Text, Elem

ul(x...) = Elem(:xhtml, :ul, x)
li(x...) = Elem(:xhtml, :li, x)

facts("Testing Nodes") do
    context("testing counts") do
        @fact count(Text("a")) => 0
        @fact count(ul()) => 0
        @fact count(li("x")) => 1
        @fact count(ul(li("x"))) => 2
        @fact count(ul(li("x"), li("x"))) => 4
    end
end

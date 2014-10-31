using Patchwork, Patchwork.HTML5
using FactCheck

import Patchwork: count, Text, Elem

facts("Testing Nodes") do
    context("testing counts") do
        @fact count(Text("a")) => 0
        @fact count(ul()) => 0
        @fact count(li("x")) => 1
        @fact count(ul(li("x"))) => 2
        @fact count(ul(li("x"), li("x"))) => 4
    end
end

using Patchwork
using FactCheck

import Patchwork: count, TextNode, Elem

ul(x...) = Elem(:xhtml, :ul, x)
li(x...) = Elem(:xhtml, :li, x)

facts("Testing Nodes") do
    context("testing counts") do
        @fact count(TextNode("a")) --> 0
        @fact count(ul()) --> 0
        @fact count(li("x")) --> 1
        @fact count(ul(li("x"))) --> 2
        @fact count(ul(li("x"), li("x"))) --> 4
    end
end

facts("Testing nested node creation") do
  node = Elem(:div, TextNode("a"))
  @fact count(node) --> 1
end

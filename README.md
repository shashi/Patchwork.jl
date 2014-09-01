# Patchwork

[![Build Status](https://travis-ci.org/shashi/Patchwork.jl.svg?branch=master)](https://travis-ci.org/shashi/Patchwork.jl)

WIP library for composing persistent XML and HTML documents.

```julia
julia> using Patchwork, Patchwork.HTML5

julia> greet(name) = body(h1("Hey " >> name) >>
                                 p("Welcome to the machine", class="welcome"))
```

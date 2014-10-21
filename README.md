# Patchwork

[![Build Status](https://travis-ci.org/shashi/Patchwork.jl.svg?branch=master)](https://travis-ci.org/shashi/Patchwork.jl)

WIP library for composing persistent XML and HTML documents.

## Usage

In IJulia:

```julia
using Patchwork, Patchwork.HTML5

greet(name) = h1("Hey " + name) + p("Welcome to the machine.", class="welcome")

greet("You")
```

## Development

You will need a recent `nodejs` and `npm` installed to hack on the JavaScript part of this package.

To build the JS files run the following from `runtime/` directory:

```sh
npm install .
npm install -g browserify
make
```

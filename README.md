# Patchwork

<!--[![Build Status](https://travis-ci.org/shashi/Patchwork.jl.svg?branch=master)](https://travis-ci.org/shashi/Patchwork.jl) -->

A library for [DOM](http://www.w3.org/TR/WD-DOM/introduction.html) representation in Julia supporting [element creation](#creating-elements), [diff computation](#diff-computation) and [browser-side patching](#javascript-setup-and-patching) for efficient re-rendering in interactive browser-based interfaces.

## Creating Elements

The `Elem` constructor can be used to create an element.

```julia
# E.g.
using Patchwork

Elem(:h1, "Hello, World!")
```
creates an `h1` heading element which reads "Hello, World!"

You can attach any property (e.g. `className`, `style`, `height`, `width`) that you would like the DOM node to have by passing it as a keyword argument to `Elem`

```julia
# E.g.
Elem(:h1, "Hello, World!", style=[:color => :white, :backgroundColor => :black])
```
creates a `h1` with white text on a black background.

You can nest elements inside another
```julia
Elem(:div, [
    Elem(:h1, "Hello, World!"),
    Elem(:p, "How are you doing today?")])
```

The `Patchwork.HTML5` module gives you helper functions which are named after the HTML elements, allowing you to create nodes in a concise DSL-esque way. There is similarly also Patchwork.SVG.

```julia
div(
    h1("Hello, World!", style=[:color=>:green]),
    p("How are you doing today?"))
```

`Elem`s objects are immutable and have the `children` and `attributes` fields that are immutable vector and immutable hash map respectively. There are some operators which you can use to add properties or elements to another without explicitly constructing a new `Elem`.

The `&` operator can set attributes
```julia
# E.g.
div_with_class = div("This div's class can change") & [:className => "shiny"]
```
The `<<` operator can append an element to the end of another.

```julia
h1_and_p = div(h1("Hello, World!") << p("How are you doing today?"))
```

## Diff computation

It is possible to compute the difference between two elements. This is done with the function `diff`.

```julia
# E.g.
patch = diff(left::Elem, right::Elem)
```
returns a "patch". A patch is a `Dict` which maps node indices to a list of patches on that node. (a node is either an `Elem` or a `Text`). The node index is a number representing the position of the node in a depth-first ordering starting from the `left` node itself whose index is 0.

Since `Elem`s are based on immutable datastructures, referential equality suffices to show that two subtrees or `children` or `attributes` are the same. Hence the more structure two nodes share, the faster the diffing.

For example, if you have a big `Elem`, say `averybigelem`, the running time of the following diff call

```julia
diff(averybigelem, averybigelem & [:className => "shiny"])
```

will not depend on the size and complexity of `averybigelem` because diffing gets *short-circuited* since `left.children === right.children`. It will probably be helpful to keep this in mind while building something with Patchwork.

## JavaScript setup and patching

Patchwork has a javascript "runtime" in `runtime/build.js` that needs to be included into a page where you would like to display Patchwork nodes.

```html
<script src="/path/to/build.js"></script>
```

This is automatically done for you when using Patchwork from IJulia.

Patchwork defines `writemime(io::IO, ::MIME"text/html", ::Elem)` method which can use this runtime to display nodes and/or apply patches to nodes that are already displayed.

At a lower level, the runtime exposes the window.Patchwork object, which can be used to render nodes from their JSON representations and patch them.

```js
// E.g.
node = new Patchwork.Node(mountId, elemJSON)
```
this renders the node represented by `elemJSON` and appends it to a DOM element with id `mountId`.

`Patchwork.Node` instances have an `applyPatch` method which can be used to patch the node.

```js
// E.g.
node.applyPatch(patchJSON)
```

## Usage in IJulia

When you load Patchwork in IJulia, the runtime is setup automatically for you. If the result of executing a cell is an `Elem` object, it gets rendered in the cell's output. `display(::Elem)` will work too.

When used with [Reactive](http://julialang.org/Reactive.jl), any `Signal{Elem}` values (see [Reactive.Signal](http://julialang.org/Reactive.jl/#signals)) get displayed with their initial value first. Subsequent updates are sent as patches and applied at the front-end.

## Setup instructions

I am working on making this as simple as `Pkg.add("Patchwork")` but until then, you will need to take the following steps:

* `Pkg.clone("git://github.com/shashi/Patchwork.jl")`
* `Pkg.clone("FunctionalCollections")`

## Development

You will need a recent `nodejs` and `npm` installed to hack on the JavaScript part of this package.

To build the JS files run the following from `runtime/` directory:

```sh
npm install .
npm install -g browserify
make
```

## Thanks

This package is largely based on Matt Esch's excellent [virtual-dom](https://github.com/Matt-Esch/virtual-dom) and [vtree](https://github.com/Matt-Esch/vtree) JavaScript modules. Patchwork's JS runtime makes use of and extends these.


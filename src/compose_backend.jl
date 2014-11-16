import Compose: Context,
                ComposeNode,
                Container,
                ContainerPromise,
                Backend,
                draw,
                size_measure,
                isabsolute,
                iswithjs,
                iswithoutjs,
                clip,
                default_fill_color,
                default_stroke_color,
                default_font_size,
                default_line_width,
                Transform,
                IdentityTransform,
                UnitBox,
                nil_unit_box,
                hright,
                hcenter,
                vcenter,
                vtop,
                combine,
                order,
                isscalar,
                realize,
                absolute_units,
                ParentDrawContext,
                svg_fmt_color,
                svg_fmt_float,
                print_svg_path,
                AbsoluteBoundingBox,
                Property,
                PropertyPrimitive,
                Form,
                BitmapPrimitive,
                CirclePrimitive,
                CurvePrimitive,
                EllipsePrimitive,
                LinePrimitive,  
                PathPrimitive,
                PolygonPrimitive,
                RectanglePrimitive,
                TextPrimitive,
                ClipPrimitive,
                FillOpacityPrimitive,
                FillPrimitive,
                FontPrimitive,
                FontSizePrimitive,
                JSCallPrimitive,
                JSIncludePrimitive,
                LineWidthPrimitive,
                SVGAttributePrimitive,
                SVGClassPrimitive,
                SVGIDPrimitive,
                StrokeDashPrimitive,
                StrokeLineCapPrimitive,
                StrokeLineJoinPrimitive,
                StrokeOpacityPrimitive,
                StrokePrimitive,
                VisiblePrimitive,
                Point

using Color

# The Patchable backend
export Patchable, draw

type Patchable <: Backend
    width::Float64
    height::Float64

    jsheader::Vector{String}
    jsmodules::Vector{(String, String)}
    clip_paths::Dict{ClipPrimitive, String}
    vector_properties::Vector
    function Patchable(width, height, absolute_elems=Elem[])
        width = size_measure(width)
        height = size_measure(height)
        if !isabsolute(width) || !isabsolute(height)
            error("SVG image size must be specified in absolute units.")
        end
        new(width.abs,
            height.abs,
            String[],
            (String, String)[],
            Dict{ClipPrimitive, String}(),
            Any[])
    end
end

iswithjs(::Patchable) = false
iswithousjs(::Patchable) = true

vector_properties(img::Patchable) = if !isempty(img.vector_properties)
    img.vector_properties[end]
end

clip_path_id(img, path) =
   if (haskey(img.clip_paths, path))
       return img.clip_paths[path]
   else
       id = string("clippath-", length(img.clip_paths) + 1)
       img.clip_paths[path] = id
       return id
   end

# Declare that we need the recursive drawing procedure
function draw(img::Patchable, root::Context)
    root = Elem(:svg, :svg,
         draw_recursive(img, root),
         width=string(img.width, "mm"),
         height=string(img.height, "mm"),
         viewBox=string("0 0 ", img.width, ' ', img.height),
         stroke=svg_fmt_color(default_stroke_color),
         fill=svg_fmt_color(default_fill_color))

    root &= ["stroke-width" => svg_fmt_float(default_line_width.abs),
             "font-size" => svg_fmt_float(default_font_size.abs)]

    if !isempty(img.clip_paths)
        defs = Elem(:svg, :defs)
        for (path, id) in img.clip_paths
            defs <<= Elem(:svg, :clipPath,
                          Elem(:svg, :path, d=svg_fmt_path(path.points)),
                          id=id)
        end
        root = root << defs
    end
    root
end

root_box(img::Patchable) =
    AbsoluteBoundingBox(0.0, 0.0, img.width, img.height)

init_context(::Patchable, ::Context) = nothing

typealias SVGPart Union(Elem, Dict, Nothing)

addto(::Patchable, acc::Nothing, child::Nothing) = nothing
addto(::Patchable, acc::Nothing, child::SVGPart) = child
addto(::Patchable, acc::SVGPart, child::Nothing) = acc
addto(::Patchable, acc::Elem{:svg, :g}, child::Elem) = acc << child

addto(p::Patchable, acc::Nothing, child::Array) = addto(p, Elem(:svg, :g), child)
function addto(p::Patchable, acc::Elem{:svg, :g}, child::Array)
    for i=1:length(child)
        @inbounds acc = addto(p, acc, child[i])
    end
    acc
end

addto(::Patchable, acc::Elem, child::Elem) = Elem(:svg, :g, acc, child)
addto(::Patchable, acc::Elem, child::Dict) = acc & child
addto(::Patchable, acc::Nothing, child::Dict) = Elem(:svg, :g) & child

function push_property_frame(img::Patchable, vector_props)
    push!(img.vector_properties, vector_props)
end

function properties_at_index(img, prop_vecs, i)
    props = Dict()
    for (proptype, property) in prop_vecs
        if i > length(property.primitives)
            error("Vector of properties and vector of forms have different length")
        end
        draw!(img, property.primitives[i], props)
    end
    props
end

function pop_property_frame(img::Patchable)
    pop!(img.vector_properties)
end

# Form Drawing
# ------------

function draw(img::Patchable, form::Form)
    acc = Array(Any, length(form.primitives))
    properties = vector_properties(img)

    for i in 1:length(form.primitives)
        elem = draw(img, form.primitives[i])
        if properties !== nothing && !isempty(properties)
            props = properties_at_index(img, properties, i)
            elem = addto(img, elem, props)
        end
        acc[i] = elem
    end
    acc
end


function draw(img::Patchable, prim::BitmapPrimitive)
    warn("Patchable backend does not yet support bitmap primitives")
    nothing
end

draw(img::Patchable, prim::CirclePrimitive) =
    Elem(:svg, :circle,
         cx=prim.center.x.abs,
         cy=prim.center.y.abs,
         r=prim.radius.abs)

draw(img::Patchable, prim::CurvePrimitive) =
    Elem(:svg, :path,
         fill="none",
         path=string("M" 
                     , prim.anchor0.x.abs, ','
                     , prim.anchor0.y.abs, "C"
                     , prim.ctrl0.x.abs, ','
                     , prim.ctrl0.y.abs, ' '
                     , prim.ctrl1.x.abs, ','
                     , prim.ctrl1.y.abs, ' '
                     , prim.anchor1.x.abs, ','
                     , prim.anchor1.y.abs))

function draw(img::Patchable, prim::EllipsePrimitive)
    cx = prim.center.x.abs
    cy = prim.center.y.abs
    rx = sqrt((prim.x_point.x.abs - cx)^2 +
              (prim.x_point.y.abs - cy)^2)
    ry = sqrt((prim.y_point.x.abs - cx)^2 +
              (prim.y_point.y.abs - cy)^2)
    theta = rad2deg(atan2(prim.x_point.y.abs - cy,
                          prim.x_point.x.abs - cx))

    if !all(isfinite([cx, cy, rx, ry, theta]))
        return nothing
    end
    el = Elem(:svg, :ellipse,
              cx=cx, cy=cy, rx=rx, ry=ry)
    if abs(theta) > 1e-4
        el = el & [:transform => string("rotate(",
                                        svg_fmt_float(theta), ' ',
                                        svg_fmt_float(cx), ' ',
                                        svg_fmt_float(cy), ')')]
    end
    el
end

function svg_fmt_path(points::Vector{Point}, bridge_gaps::Bool=false)
    io=IOBuffer()
    print_svg_path(io, points, bridge_gaps)
    takebuf_string(io)
end

function draw(img::Patchable, prim::LinePrimitive)
     n = length(prim.points)
     if n <= 1; return; end

     Elem(:svg, :path, fill="none", d=svg_fmt_path(prim.points, true))
end

function svg_fmt_path_ops(ops)
    io = IOBuffer()
    for op in ops
        svg_print_path_op(io, op)
    end
    takebuf_string(io)
end

draw(img::Patchable, prim::PathPrimitive) =
    Elem(:svg, :path, d=svg_fmt_path_ops(prim.ops))

function draw(img::Patchable, prim::PolygonPrimitive)
     n = length(prim.points)
     if n <= 1; return; end

     Elem(:svg, :path, d=svg_fmt_path(prim.points, true) * " z")
end

function draw(img::Patchable, prim::RectanglePrimitive)
    width = max(prim.width.abs, 0.01)
    height = max(prim.height.abs, 0.01)

    Elem(:svg, :rect,
         x=prim.corner.x.abs,
         y=prim.corner.y.abs,
         width=width,
         height=height)
end

function draw(img::Patchable, prim::TextPrimitive)
    el = pango_to_elems(prim.value) & [
            :x=>prim.position.x.abs,
            :y=>prim.position.y.abs]
    if is(prim.halign, hcenter)
        el &= ["text-anchor" => "middle"]
    elseif is(prim.halign, hright)
        el &= ["text-anchor" => "end"]
    end
    if is(prim.valign, vcenter)
        el &= [:dy=>"0.35em"]
    elseif is(prim.halign, vtop)
        el &= [:dy=>"0.6mm"]
    end

    if abs(prim.rot.theta) > 1e-4
        el &= [:transform => string("rotate(",
                                     rad2deg(prim.rot.theta), ' ',
                                     svg_fmt_float(prim.rot.offset.x.abs), ' ',
                                     svg_fmt_float(prim.rot.offset.y.abs), ')')]
     end
     el

end

# Property Primitives
# -------------------
function draw(img::Patchable, prop::Property)
    dict = Dict()
    for prim in prop.primitives
        draw!(img, prim, dict)
    end
    dict
end

function draw!(img::Patchable, prim::PropertyPrimitive, dict)
    item = draw(img, prim)
    if !is(item, nothing)
        k, v = item

        dict[k] = v
    end
end

function draw(img::Patchable, prim::ClipPrimitive)
    id = clip_path_id(img, prim)
    "clip-path", "url(#$id)"
end

draw(img::Patchable, prim::FillOpacityPrimitive) =
    :opacity, prim.value

function draw!(img::Patchable, prim::FillPrimitive, props)
    if isa(prim.color, AlphaColorValue)
        props[:fill] = svg_fmt_color(prim.color.c)
        props["fill-opacity"] = prim.color.alpha
    elseif isa(prim.color, ColorValue)
        props[:fill] = svg_fmt_color(prim.color)
    else
        props[:fill] = "none"
    end
end

draw(img::Patchable, prim::FontPrimitive) =
    "font-family", escape_string(prim.family)

draw(img::Patchable, prim::FontSizePrimitive) =
    "font-size", prim.value.abs

function draw(img::Patchable, prim::JSCallPrimitive)
    nothing
end

function draw(img::Patchable, prim::JSIncludePrimitive)
    push!(img.jsheader, prim.value)
    if prim.jsmodule != nothing
        push!(img.jsmodules, prim.jsmodule)
    end
    nothing
end

draw(img::Patchable, prim::LineWidthPrimitive) =
    "stroke-width", prim.value.abs

draw(img::Patchable, prim::SVGAttributePrimitive) = nothing
    #prim.attribute, escape_string(prim.value)

draw(img::Patchable, prim::SVGClassPrimitive) =
    :class, escape_string(prim.value)

draw(img::Patchable, prim::SVGIDPrimitive) =
    :id, escape_string(prim.value)

function draw(img::Patchable, prim::StrokeDashPrimitive)
    if isempty(prim.value)
        "stroke-dasharray", :none
    else
        "stroke-dasharray", join([v.abs for v in prim.value], ',')
    end
end

draw(img::Patchable, prim::StrokeLineCapPrimitive) =
    "stroke-linecap", svg_fmt_linecap(prim.value)

draw(img::Patchable, prim::StrokeLineJoinPrimitive) =
    "stroke-linejoin", svg_fmt_linejoin(prim.value)

draw(img::Patchable, prim::StrokeOpacityPrimitive) =
    "stroke-opacity", prim.value

function draw!(img::Patchable, prim::StrokePrimitive, dict)
    if isa(prim.color, AlphaColorValue)
        dict[:stroke] = svg_fmt_color(prim.color.c)
        dict["stroke-opacity"] = property.color.value
    else
        dict[:stroke] = svg_fmt_color(prim.color)
    end
end

draw(img::Patchable, prim::VisiblePrimitive) =
    :visibility, prim.value ? "visible" : "hidden"

# Pango markup to Patchwork
function pango_to_elems(text::String)
    pat = r"<(/?)\s*([^>]*)\s*>"
    input = text
    output = Elem[Elem(:svg, :text)] # Stack
    lastpos = 1

    baseline_shift = 0.0
    open_tag = false

    for mat in eachmatch(pat, text)
        txt = input[lastpos:mat.offset-1]
        if length(txt) > 0
            output[end] <<= Patchwork.Text(txt)
        end

        closing_tag = mat.captures[1] == "/"

        if open_tag && !closing_tag
            el = pop!(output)
            output[end] <<= el
        end

        if mat.captures[2] == "sup"
            if mat.captures[1] == "/"
                el = pop!(output)
                output[end] <<= el
            else
                el = Elem(:svg, :tspan,
                         style=["dominant-baseline" => :inherit],
                         dy="-0.6em") & ["font-size" => "83%"]
                push!(output, el)
                baseline_shift = -0.6 * 0.83
            end
        elseif mat.captures[2] == "sub"
            if mat.captures[1] == "/"
                el = pop!(output)
                output[end] <<= el
            else
                el = Elem(:svg, :tspan,
                          style=["dominant-baseline" => :inherit],
                          dy="0.6em") & ["font-size" => "83%"]
                push!(output, el)
                baseline_shift = 0.6 * 0.83
            end
        elseif mat.captures[2] == "i"
            if mat.captures[1] == "/"
                el = pop!(output)
                output[end] <<= el
            else
                el = Elem(:svg, :tspan,
                          style=["dominant-baseline" => :inherit]) & ["font-style"=>"italic"]
                push!(output, el)
            end
        elseif mat.captures[2] == "b"
            if mat.captures[1] == "/"
                el = pop!(output)
                output[end] <<= el
            else
                el = Elem(:svg, :tspan,
                          style=["dominant-baseline" => :inherit]) & ["font-style"=>"bold"]
                push!(output, el)
            end
        end

        if closing_tag && baseline_shift != 0.0
            el = Elem(:svg, :tspan,
                      dy="$(-baseline_shift)em")
            push!(output, el)
            baseline_shift = 0.0
            open_tag = true
        end

        lastpos = mat.offset + length(mat.match)
    end
    txt = input[lastpos:end]
    if length(txt) > 0
        output[end] <<= Patchwork.Text(string(txt))
    end
    if open_tag
        el = pop!(output)
        output[end] <<= el
    end
    output[1]
end

function draw_recursive(backend::Backend,
                        container::ContainerPromise,
                        transform=IdentityTransform(),
                        units=UnitBox(),
                        parent_box=root_box(backend))
    container = realize(container,
                        ParentDrawContext(transform, units, parent_box))
    if !isa(container, Container)
        error("Error: A container promise function did not evaluate to a container")
    end
    draw_recursive(backend, container, transform, units, parent_box)
end

function draw_recursive(backend::Backend,
                        ctx::Context,
                        parent_transform=IdentityTransform(),
                        units=UnitBox(),
                        parent_box=root_box(backend))

        if (iswithjs(ctx) && !iswithjs(backend)) ||
           (iswithoutjs(ctx) && iswithjs(backend))
            return nothing
        end

        box = absolute_units(ctx.box, parent_transform, units, parent_box)
        rot = absolute_units(ctx.rot, parent_transform, units, box)
        transform = combine(convert(Transform, rot), parent_transform)

        if ctx.units != nil_unit_box
            units = absolute_units(ctx.units, transform, units, box)
        end

        acc = init_context(backend, ctx)

        if ctx.clip
            x0 = ctx.box.x0
            y0 = ctx.box.y0
            x1 = x0 + ctx.box.width
            y1 = y0 + ctx.box.height
            _clip = absolute_units(clip(Point(x0, y0), Point(x1, y0),
                                        Point(x1, y1), Point(x0, y1)),
                                   parent_transform, units, parent_box)

            acc = addto(backend, acc, draw(backend, _clip))
        end

        child_containers = Any[]
        vector_properties = Dict{Type, Property}()

        for child in ctx.children
            if isa(child, Property)
                # Properties get the parent units
                prop = absolute_units(child, parent_transform, units, parent_box)
                if isscalar(child)
                    acc = addto(backend, acc, draw(backend, prop))
                else
                    vector_properties[typeof(child)] = child
                end
            end
        end

        pop_frame = false
        if !isempty(vector_properties)
            push_property_frame(backend, vector_properties)
            pop_frame = true
        end
        for child in ctx.children
            if isa(child, Form)
                # this draw call calls draw(backend, absolute_form)
                acc = addto(backend, acc, draw(backend, transform, units, box, child))
            elseif isa(child, Container)
                push!(child_containers, (order(child), length(child_containers) + 1, child))
            end
        end

        sort!(child_containers)
        for child in child_containers
            ord, len, container = child
            acc = addto(backend, acc, draw_recursive(backend, container, transform, units, box))
        end

        if pop_frame
            pop_property_frame(backend)
        end

        empty!(child_containers)

        acc
end


# writemime for signals
if Pkg.installed("Reactive") >= v"0.0.0"

    import Base: writemime
    import Reactive: Signal
    import Compose

    if isdefined(Main, :IJulia)
        import IJulia: metadata
        metadata{T <: ComposeNode}(::Signal{T}) = Dict()
    end

    function writemime{T <: ComposeNode}(io::IO, m::MIME"text/html", ctx::Signal{T})
        import Gadfly: Plot, draw, default_plot_width, default_plot_height
        writemime(io, m, lift(c -> draw(
            Patchable(
                Compose.default_graphic_width,
                Compose.default_graphic_height
            ), c), ctx))
    end

    if Pkg.installed("Gadfly") > v"0.0.0"
        import Gadfly

        if isdefined(Main, :IJulia)
            import IJulia: metadata
            metadata(::Signal{Gadfly.Plot}) = Dict()
        end

        function writemime(io::IO, m::MIME"text/html", plt::Signal{Gadfly.Plot})
            writemime(io, m, lift(p -> Gadfly.draw(
               Patchable(
                    Compose.default_graphic_width,
                    Compose.default_graphic_height
                ), p), plt))
        end
    end

end



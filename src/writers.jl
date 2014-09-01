abstract Writer

immutable MinifiedHTML5 <: Writer end
immutable PrettyHTML5 <: Writer end
immutable MinifiedXML <: Writer end
immutable PrettyXML <: Writer end


# Write HTML
writehtml(io::IO, t::Text) =
    write(io, t.content)

writehtml{name}(io::IO, a::Attr{name}) =
    write(io, " ", name, "=\"", string(a.value), "\"")

function writehtml(io::IO, doc::Document)
    write(io, doc.doctype, "\n")
    writehtml(io, elem(:html, ElemList(doc.head, doc.body)))
end

function writehtml{tag}(io::IO, el::Parent{tag})
    write(io, "<", tag)
    for a in el.attrs
        writehtml(io, a)
    end
    write(io, ">")
    writehtml(io, el.content)
    write(io, "</", tag, ">")
end

function writehtml{tag}(io::IO, el::Leaf{tag})
    write(io, "<", tag)
    for a in el.attrs
        writehtml(io, a)
    end
    write(io, "/>")
end

writehtml(io::IO, el::EmptyElem) =
    write(io, "")

function writehtml(io::IO, el::ElemList)
    writehtml(io, el.first)
    writehtml(io, el.rest)
end

writemime(io::IO, m::MIME"text/html", x::Html) =
    writehtml(io, x)

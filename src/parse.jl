# A rudimentary XML parser

export parse_elems

namespace{ns}(el::Elem{ns}) = ns
tag{ns, tag}(el::Elem{ns, tag}) = tag

function make_tag(str)
    # This function will get strings such as /tag>
    # or tag attr="val"...>

    if first(str) == '/'
        # this is a closing tag.
        ms = match(r"^/([a-zA-Z\-_0-9]+)>", str)
        if ms === nothing
            error("Invalid closing tag, $str")
        end
        tag = ms.captures[1]
        return Elem(:closing_tag, Symbol(tag)) # Hack alert!
    else
        # this is an opening tag
        ms = match(r"^([a-zA-Z\-_0-9]+)\s*(.*)>", str)
        if ms === nothing
            error("Invalid opening tag, $str")
        end
        tag = ms.captures[1]
        attrs = ms.captures[2]
        if attrs != ""
            attr_ms = matchall(r"([^\s=]*\s*=\s*[^\s=]*)", attrs)
            attr = Any[split(s, "=") for s in attr_ms]
            kvs = Any[(k, strip(v, Set("\"' "))) for (k, v) in attr]
            return Elem(Symbol(tag)) & kvs
        else
            return Elem(Symbol(tag))
        end
    end
end

# Given a string, returns a vector of elements
function parse_elems(str::AbstractString, ns=:xhtml)

    node_stack = Node[Elem(:wrapper, :dummy)] # hack again

    i = start(str)

    while !done(str, i)
        c, i = next(str, i)
        if c == '<'
            j = search(str, '>', i)
            if j===0
                error("Tag at $i never closes?")
            end
            el = make_tag(str[i:j])
            if namespace(el) !== :closing_tag
                # A tag just opened, push it to the stack
                push!(node_stack, el)
            else
                # A tag just closed, check to see if it was on top
                top_el = pop!(node_stack)
                if tag(top_el) === tag(el)
                    # yes, you just closed the tag that you were supposed to
                    # add it to the previous elem in the stack
                    parent = pop!(node_stack)
                    push!(node_stack, parent << top_el)
                else
                    error("Wrong closing tag at $i")
                end
            end
        else
            i = prevind(str, i)
            j = search(str, '<', i)
            if j==0
                substr = str[i:end]
                el = pop!(node_stack)
                push!(node_stack, el << TextNode(str[i:end]))
                break
            else
                el = pop!(node_stack)
                j = prevind(str, j)
                push!(node_stack, el << TextNode(str[i:j]))
            end
        end
        i = j
        c, i = next(str, i)
    end

    if length(node_stack) !== 1
        error("Looks like the HTML is malformed. Is there an un closed tag?")
    else
        el = pop!(node_stack)
        return children(el)
    end
end

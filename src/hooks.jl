export PropHook

immutable PropHook
    _hook::UTF8String
    val
end

function diff(a::PropHook, b::PropHook)
    val = diff(a.val, b.val)
    val === nothing ? nothing : PropHook(b._hook, val)
end

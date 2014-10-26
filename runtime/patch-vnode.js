var mutateNode = require("./vnode-patch-op")

module.exports = patchVNode

function patchVNode(root, patches) {

    linkParents(root)
    for (var key in patches) {
        if (key === "a") continue
        patch = patches[key]
        mutateNode(patch.type, patch.vNode, patch.patch)
    }

    return root
}

function linkParents(vNode) {
    if (!vNode || !vNode.children) { return }

    var children = vNode.children
    for (var i=0, l=children.length; i < l; i++) {
        children[i].up = vNode
        linkParents(children[i])
    }
}

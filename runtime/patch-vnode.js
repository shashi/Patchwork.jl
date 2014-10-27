var mutateNode = require("./vnode-patch-op")
var isArray = require('x-is-array')

module.exports = patchVNode

function patchVNode(root, patches) {

    linkParents(root)

    for (var key in patches) {
        if (key === "a") continue
        patch = patches[key]
        if (isArray(patch)) {

            for (var i=0, l=patch.length; i < l; i++) {
                mutateNode(patch[i].type, patch[i].vNode, patch[i].patch)
            }
        } else {
            mutateNode(patch.type, patch.vNode, patch.patch)
        }
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

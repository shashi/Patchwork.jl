var version = require("vtree/version")

module.exports = isVirtualPatch

function isVirtualPatch(x) {
    return x && x.type === "VirtualPatch" && x.version === version
}

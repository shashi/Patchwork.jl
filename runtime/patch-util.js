isObject = require('is-object')

module.exports = {reorder: reorder,
                  patchObject: patchObject}

function reorder(array, moves) {
    if (!arr) { return }
    var copy = array.slice(0)

    for (var i=0, l=array.length; i < l; i++) {
        var move = moves[i]
        if (move !== undefined) {
            array[move] = copy[i]
        }
    }
    return array
}

function patchObject(obj, patch) {
    for (var key in patch) {
        if (patch[key] && typeof patch[key].hook == "function") {
            obj[key] = patch[key]
        } else if (isObject(patch[key]) && isObject(obj[key])) {
            obj[key] = patchObject(obj[key], patch[key]);
        } else {
            obj[key] = patch[key]
        }
    }
}


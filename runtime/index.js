var VNode = require('vtree/vnode');
var VText = require('vtree/vtext');
var diff = require('virtual-dom/diff');
var patch = require('virtual-dom/patch');
var createElement = require('virtual-dom/create-element');


var P = {
    NAMESPACES: {
        "xhtml": "http://www.w3.org/1999/xhtml",
        "svg": "http://www.w3.org/2000/svg"
    },
    debugLog: function () {
        console.log(arguments);
    },
    render: function (id, jlNode) {
        var outer = document.getElementById(id),
            vnode = P.makeVNode(jlNode),
            el = createElement(vnode);
            
        outer.appendChild(el);
        return el;
    },
    makeVNode: function (jlNode) {
        if ('text' in jlNode) {
           return new VText(jlNode.text);
        }

        vnode = new VNode(jlNode.tagName, jlNode.properties,
                          _.map(jlNode.children, P.makeVNode),
                          jlNode.key, P.NAMESPACES[jlNode.namespace]);
        P.debugLog(vnode, createElement(vnode))
        return vnode;
    }
}

window.Patchwork = P;

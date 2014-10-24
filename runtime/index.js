var VNode = require('vtree/vnode');
var VText = require('vtree/vtext');
var VPatch = require('vtree/vpatch');
var diff = require('virtual-dom/diff');
var patch = require('virtual-dom/patch');
var createElement = require('virtual-dom/create-element');


function Patchwork(el, jlNode) {
    if (typeof el == "string") {
        el = document.getElementById(el);
    }
    this.element = el
    if (jlNode) {
        // Note: makes this.root
        this.mount(
            Patchwork.makeVNode(jlNode)
        );
    }
}

var P = Patchwork;

// Utilities
_.extend(Patchwork, {
    NAMESPACES: {
        "xhtml": "http://www.w3.org/1999/xhtml",
        "svg": "http://www.w3.org/2000/svg",
        null: "http://www.w3.org/1999/xhtml"
    },
    refDiff: function (a, b) {
        return diff(P.makeVNode(a), P.makeVNode(b));
    },
    makeVNode: function (jlNode) {
        if ('text' in jlNode) return new VText(jlNode.text);
        return new VNode(jlNode.tagName, jlNode.properties,
                         _.map(jlNode.children, Patchwork.makeVNode),
                         jlNode.key, Patchwork.NAMESPACES[jlNode.namespace]);
    },
});

Patchwork.prototype = {
    mount: function (vnode) {
        var el = createElement(vnode);
        this.element.appendChild(el);
        this.root = vnode;
        return el;
    },
    patch: function (vpatch) {
    }
}

window.Patchwork = Patchwork;

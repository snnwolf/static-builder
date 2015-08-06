'use strict';
var config = {};
config.packages = {};

config.packages.bb_main = {
    js_ext: [
        'http://code.jquery.com/jquery-1.11.3.min.js',
        '//maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js'
    ],
    css_ext: [],
    js: [
        {path: 'js/libs/jquery.magnific-popup.min.js', href: '/js/libs/jquery.magnific-popup.min.js'},
        {path: 'js/main.js', href: '/js/main.js'}
    ],
    css: [
            {path: 'css/normalize.min.css', href: '/css/normalize.min.css'},
            {path: 'css/main.css', href: '/css/main.css'}
    ]
}

config.packages.mv_main = {
    css: [
        {path: 'phone/css/bootstrap.min.css', href: '/phone/css/bootstrap.min.css'},
        {path: 'phone/css/mb.css', href: '/phone/css/mb.css'}
    ],
    js: [
        {path: 'phone/js/bootstrap.min.js', href: '/phone/js/bootstrap.min.js'},
        {path: 'phone/js/main.js', href: '/phone/js/main.js'}
    ]
}

config.distDir = 'm/';
config.baseUrl = '/m/';
config.rootPath = __dirname

module.exports = config
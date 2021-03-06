'use strict';
var config = {};
config.packages = {};

// config.packages.bb_main = {
//     js_ext: [
//         'http://code.jquery.com/jquery-1.11.3.min.js',
//         '//maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js'
//     ],
//     css_ext: [],
//     js: [
//         '/js/libs/jquery.magnific-popup.min.js',
//         '/js/main.js'
//     ],
//     css: [
//         '/css/normalize.min.css',
//         '/css/main.css'
//     ]
// }

// config.packages.mv_main = {
//     css: [
//         // '/phone/css/bootstrap.min.css',
//         '/phone/css/mb.css'
//     ],
//     js: [
//         '/phone/js/bootstrap.min.js',
//         '/phone/js/main.js'
//     ]
// }

config.packages.bower = {
    css: [
        '/lib/socicon/styles.css',
        '/css/main.css',
        '/css/*.css'
    ],
    "js": [
        '/js/admin.js',
        '/js/jquery.*.js'
    ]
}

config.distDir = 'web/m/';
config.baseUrl = '/m/';
config.rootPath = './web/';
config.outputFile = 'web/m/build.json';
config.tmp = '/tmp';
// config.debug = true
module.exports = config

###
Version: 0.0.2
###
# TODO разобраться с @include в css

'use strict'
fs = require 'fs'
path = require 'path'
util = require 'util'
# yaml = require 'js-yaml'

TMP_DIR = '/tmp/'
FILE_ENCODING = 'utf-8'
EOL = "\n"

clearDir = (dirPath, deleteRoot = false) ->
    try
        files = fs.readdirSync dirPath
    catch e
        return

    if files.length > 0
        for i in files
            filePath = "#{dirPath}/#{i}"
            if fs.statSync(filePath).isFile()
                fs.unlinkSync filePath
            else clearDir filePath
    if deleteRoot
        fs.rmdirSync dirPath, true
    return

# при случае можно использовать https://github.com/jakubpawlowicz/enhance-css
base64replace = (src, config) ->
    src = [src] if !Array.isArray(src)
    # https://github.com/zckrs/gulp-css-base64
    rImages = /url(?:\(['|"]?)(.*?)(?:['|"]?\))(?!.*\/\*base64:skip\*\/)/ig
    # console.log "read css", src
    out = src.map (filePath) ->
        files = {}
        code = fs.readFileSync filePath, FILE_ENCODING
        cssDir = path.dirname(filePath)
        code.replace rImages, (match, file, type) ->
            if file.indexOf('/') == 0
                fileName = path.normalize "#{config.rootPath}/#{file}"
            else
                fileName = path.normalize "#{cssDir}/#{file}"
            # console.log fileName, match
            if match.indexOf('data:image') > -1
                return match
            try
                if !fs.statSync(fileName).isFile()
                    console.log "Skip #{fileName} not is file"
                    return match
            catch e
                console.log "Skip #{fileName} does not exists"
                return match

            size = fs.statSync(fileName).size
            type = 'jpeg' if type == 'jpg'
            type = 'svg+xml' if type == 'svg'
            if size > 4096
                # console.log "Skip #{fileName} (" + (Math.round(size/1024*100)/100) + 'k)'
                return match
            else
                base64 = fs.readFileSync(fileName).toString('base64')
                # if typeof(files[fileName]) != 'undefined'
                #     console.log "Warning: #{fileName} has already been base64 encoded in the css"
                files[fileName] = true
                # console.log "#{fileName} ok"
                return "url(\"data:image/#{type};base64,#{base64}\")"
    return out.join(EOL)

uglify = (src, type, config) ->
    src = [src] if !Array.isArray(src)

    distDir = config.distDir or 'm/'

    if !distDir or !fs.lstatSync(distDir).isDirectory()
        throw new Error "#{distDir} is not a directory"

    md5sum = require('crypto').createHash('md5')
    code = ''

    switch type
        when 'css'
            uglifyCSS = require('uglifycss')
            code = base64replace src, config
            code = uglifyCSS.processString code
        when 'js'
            uglifyJS = require('uglify-js')
            mincode = uglifyJS.minify src,
                # outSourceMap: "#{dist}.map"
                compress: hoist_funs: false # чтобы не вырезал типа не используемый код
            code = mincode.code
        else
            throw new Error "#{type} must bee js|css"

    comment = "/**\n"
    for ff in src
        comment += " * #{ff}\n"
    comment += " */"

    distFile = md5sum.update(code).digest('hex')[0...7] + '.' + type
    dist = path.normalize distDir + '/' + distFile
    # console.log mincode.code
    # clearDir distDir
    fs.writeFileSync(dist, "#{comment}\n#{code}", FILE_ENCODING);
    # console.log src, dist
    return path.normalize "#{config.baseUrl}/#{distFile}"

# uglify ['js/functions.js', 'js/main.js'], 'js', 'm'
# uglify ['css/normalize.min.css', 'css/main.css'], 'css', 'm/'
# uglify ['phone/css/jcarousel.connected-carousels.css', 'phone/css/mb.css'], 'css'

plugin =
    build: (config) ->
        # console.log config.packages
        # TODO привести конфиг к какому-то шаблону
        # для конфигов можно использовать https://github.com/indexzero/nconf
        res = {}
        clearDir(config.distDir)
        for package_idx, package_content of config.packages
            res[package_idx] = []
            tags_tpl =
                css: "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\">"
                js: "<script type=\"text/javascript\" src=\"%s\">"
            # console.log package_idx, package_content
            if package_content.css_ext
                for l in package_content.css_ext
                    part =
                        tag: util.format tags_tpl['css'], l
                        consists_of: [util.format tags_tpl['css'], l]
                    res[package_idx].push part
                    # console.log part

            if package_content.js_ext
                for l in package_content.js_ext
                    part =
                        tag: util.format tags_tpl['js'], l
                        consists_of: [util.format tags_tpl['js'], l]
                    res[package_idx].push part

            for _type in ['css', 'js']
                if package_content[_type]
                    consists_of = []
                    files = []

                    for l in package_content[_type]
                        consists_of.push util.format tags_tpl[_type], l
                        files.push path.normalize "#{config.rootPath}/#{l}"

                    console.log package_idx, files, consists_of
                    ugilified = uglify files, _type, config
                    part =
                        tag: util.format tags_tpl[_type], ugilified
                        consists_of: consists_of
                    res[package_idx].push part

        #     if package_content.css
        #         consists_of = []
        #         list_path = []

        #         for l in package_content.css
        #             list_path.push "#{l.path}"
        #             consists_of.push util.format tags_tpl['css'], l.href

        #         # console.log package_idx, consists_of
        #         ugilified = uglify list_path, 'css', config
        #         part =
        #             tag: util.format tags_tpl['css'], ugilified
        #             consists_of: consists_of
        #         res[package_idx].push part
        # # console.log 'res', res

        fs.writeFileSync 'm/build.json', JSON.stringify(res, null, 4), FILE_ENCODING

        return

if require.main == module
    config = require './builder-config'
    plugin.build config
    # console.log util.inspect(config, { showHidden: true, depth: null })
    # console.log util.format 'srcipt url="%s"', 'http://bilder.com'
    # console.log __dirname, path.relative __dirname + '/phone/js/main.js', __dirname

# module.exports = plugin

# You need uglify
# npm install -g uglify-js
# npm link uglify-js
# Run that into node and voila bitch

'use strict'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

TMP_DIR = '/tmp/'
FILE_ENCODING = 'utf-8'
EOL = "\n"
# filesArray = require('../app/config')

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

base64replace = (src) ->
    src = [src] if !Array.isArray(src)
    rImages = /url(?:\(['|"]?)(.*?)(?:['|"]?\))(?!.*\/\*base64:skip\*\/)/ig
    # console.log "read css", src
    out = src.map (filePath) ->
        files = {}
        code = fs.readFileSync filePath, FILE_ENCODING
        cssDir = path.dirname(filePath)
        code.replace rImages, (match, file, type) ->
            if file.indexOf('/') == 0
                fileName = __dirname + file
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

uglify = (src, type, distDir) ->
    src = [src] if !Array.isArray(src)
    distDir = 'm/' if distDir == undefined

    if !distDir or !fs.lstatSync(distDir).isDirectory()
        throw new Error "#{distDir} is not a directory"

    md5sum = require('crypto').createHash('md5')
    code = ''

    switch type
        when 'css'
            uglifyCSS = require('uglifycss')
            code = base64replace src
            code = uglifyCSS.processString code
        when 'js'
            uglifyJS = require('uglify-js')
            mincode = uglifyJS.minify src,
                # outSourceMap: "#{dist}.map"
                compress: hoist_funs: false
            code = mincode.code
        else
            throw new Error "#{type} must bee js|css"

    comment = "/**\n"
    for ff in src
        comment += " * #{ff}\n"
    comment += " */"

    dist = path.normalize distDir + '/' + md5sum.update(code).digest('hex') + '.' + type.toLowerCase()
    # console.log mincode.code
    # clearDir distDir
    fs.writeFileSync(dist, "#{comment}\n#{code}", FILE_ENCODING);
    # console.log src, dist
    return "/#{dist}"

# uglify ['js/functions.js', 'js/main.js'], 'js', 'm'
# uglify ['css/normalize.min.css', 'css/main.css'], 'css', 'm/'
# uglify ['phone/css/jcarousel.connected-carousels.css', 'phone/css/mb.css'], 'css'

plugin =
    build: (cf) ->
        fs.readFile cf, 'utf8', (err, data) ->
            if err
                console.error err.stack || err.message || String err
                return
            loaded = yaml.load data
            # console.log loaded.packages
            res = {}
            clearDir('m/')
            for package_idx, package_content of loaded.packages
                res[package_idx] = []
                # console.log package_idx, package_content
                if package_content.css_ext
                    for l in package_content.css_ext
                        part =
                            tag: "<link rel=\"stylesheet\" type=\"text/css\" href=\"#{l}\">"
                            consists_of: ["<link rel=\"stylesheet\" type=\"text/css\" href=\"#{l}\">"]
                        res[package_idx].push part
                        # console.log part

                if package_content.js_ext
                    for l in package_content.js_ext
                        part =
                            tag: "<script type=\"text/javascript\" src=\"#{l}\">"
                            consists_of: ["<script type=\"text/javascript\" src=\"#{l}\">"]
                        res[package_idx].push part

                if package_content.js
                    consists_of = []
                    list_path = []
                    # if package_content.js_dir
                    #     base_path = package_content.js_dir.src
                    # base_path = loaded.dir.js.src if !base_path

                    for l in package_content.js
                        list_path.push "#{l.path}"
                        consists_of.push "<script type=\"text/javascript\" src=\"#{l.href}\">"

                    # console.log package_idx, consists_of
                    ugilified = uglify list_path, 'js'
                    part =
                        tag: "<script type=\"text/javascript\" src=\"#{ugilified}\">"
                        consists_of: consists_of
                    res[package_idx].push part

                if package_content.css
                    consists_of = []
                    list_path = []
                    # if package_content.css_dir
                    #     base_path = package_content.css_dir.src
                    # base_path = loaded.dir.css.src if !base_path

                    for l in package_content.css
                        list_path.push "#{l.path}"
                        consists_of.push "<link rel=\"stylesheet\" type=\"text/css\" href=\"#{l.href}\">"

                    # console.log package_idx, consists_of
                    ugilified = uglify list_path, 'css'
                    part =
                        tag: "<link rel=\"stylesheet\" type=\"text/css\" href=\"#{ugilified}\">"
                        consists_of: consists_of
                    res[package_idx].push part
            # console.log 'res', res

            fs.writeFileSync 'm/build.json', JSON.stringify(res, null, 4), FILE_ENCODING

            return


if require.main == module
    plugin.build path.join(__dirname, 'builder.yml')

# module.exports = plugin

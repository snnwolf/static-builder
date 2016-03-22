# TODO разобраться с @include в css
'use strict'
fs = require 'fs'
path = require 'path'
util = require 'util'
mime = require 'mime'
glob = require 'glob'
crypto = require 'crypto'

FILE_ENCODING = 'utf-8'
EOL = "\n"

class CacheFile
    constructor: (options)->
        @FILE_ENCODING = 'utf-8'
        options ?= {}
        @tmp_dir = options.tmp_dir ? require('os').tmpDir()
        @unique = crypto.createHash('md5').update(__dirname).digest('hex')[0...7]
        @def_dir = "static-builder-#{@unique}"
        @cache_dir = options.cache_dir ? path.join(@tmp_dir, @def_dir)
        # console.log @cache_dir

        try
            fs.lstatSync @cache_dir
        catch
            fs.mkdirSync @cache_dir

    checksum: (p) ->
        if Array.isArray(p)
            str = []
            for i in p
                str.push(fs.readFileSync(i, @FILE_ENCODING))
            str = str.join('')
        else
            str = fs.readFileSync(p, @FILE_ENCODING)
        return crypto.createHash('md5').update(str).digest('hex')

    get: (key) ->
        try
            cache_file = path.join(@cache_dir, key)
            return fs.readFileSync cache_file, @FILE_ENCODING
        catch e
            return false

    set: (key, data) ->
        filepath = path.join(@cache_dir, key)
        fs.writeFileSync(filepath, data, @FILE_ENCODING)

    audit: (exclude_cs) ->
        files = fs.readdirSync(@cache_dir)
        if files.length == 0
            return
        exclude_cs ?= []
        now = new Date()
        for i in files
            if exclude_cs.indexOf(i) > -1
                continue
            filepath = "#{@cache_dir}/#{i}"
            stat = fs.statSync(filepath)
            if stat.isFile()
                fs.unlinkSync filepath
                # console.log filepath, 'deleted'

    del: (key) ->
        filepath = path.join(@cache_dir, key)
        try
            if fs.statSync(filepath).isFile()
                fs.unlinkSync(filepath)
        catch
            return

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
# TODO пропускать комментарии
base64replace = (src, config) ->
    src = [src] if !Array.isArray(src)
    # https://github.com/zckrs/gulp-css-base64
    rImages = /url(?:\(['|"]?)(.*?)(?:['|"]?\))(?!.*\/\*base64:skip\*\/)/ig

    # console.log "read", src
    out = src.map (filePath) ->
        console.log "\#\# CSS::#{filePath}" if config.debug
        files = {}

        code = fs.readFileSync filePath, FILE_ENCODING
        cssDir = path.dirname(filePath)
        return code.replace rImages, (match, file) ->
            # вдруг уже была замена
            if match.indexOf('data:image') > -1
                return match

            relativeFilePath = path.normalize(path.relative(config.distDir, cssDir) + '/' + file)
            relativeMatch = "url(#{relativeFilePath})"

            if config.allowedExt.indexOf(path.extname(file)) < 0
                # для шрифтов из других папопк, типа /phone/fonts
                # console.log "Формат в игноре #{file}", relativeMatch
                return relativeMatch

            if file.indexOf('/') == 0
                fileName = path.normalize "#{config.rootPath}/#{file}"
            else
                fileName = path.normalize "#{cssDir}/#{file}"
            # console.log fileName, match

            try
                if !fs.statSync(fileName).isFile()
                    console.log "Skip #{fileName} not is file"
                    return match
            catch e
                console.log "Skip #{fileName} does not exists"
                return match

            size = fs.statSync(fileName).size

            if size > config.maxFileSize
                console.log "Skip #{fileName} (" + (Math.round(size/1024*100)/100) + 'k)' if config.debug
                return relativeMatch # match
            else
                base64 = fs.readFileSync(fileName).toString('base64')
                # if typeof(files[fileName]) != 'undefined'
                #     console.log "Warning: #{fileName} has already been base64 encoded in the css"
                files[fileName] = true
                # console.log "#{fileName} ok"
                return "url(\"data:"+mime.lookup(file)+";base64,#{base64}\")"

    return out.join(EOL)

uglify = (src, type, config) ->
    src = [src] if !Array.isArray(src)

    if !config.distDir or !fs.lstatSync(config.distDir).isDirectory()
        throw new Error "#{config.distDir} is not a directory"

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
                mangle: false # для нормальной сборки angular
            code = mincode.code
        else
            throw new Error "#{type} must bee js|css"

    comment = "/**\n"
    for ff in src
        ff = ff.replace config.rootPath, ''
        comment += " * #{ff}\n"
    comment += " */"

    # distFile = crypto.createHash('md5').update(code).digest('hex')[0...7] + '.' + type
    # dist = path.normalize config.distDir + '/' + distFile
    # console.log mincode.code
    # clearDir config.distDir
    return "#{comment}\n#{code}"
    # fs.writeFileSync(dist, "#{comment}\n#{code}", FILE_ENCODING);
    # console.log src, dist
    # return path.normalize "#{config.baseUrl}/#{distFile}"

# uglify ['js/functions.js', 'js/main.js'], 'js', 'm'
# uglify ['css/normalize.min.css', 'css/main.css'], 'css', 'm/'
# uglify ['phone/css/jcarousel.connected-carousels.css', 'phone/css/mb.css'], 'css'

plugin =
    build: (config) ->
        # console.log config.packages
        # для конфигов можно использовать https://github.com/indexzero/nconf
        res = {}
        config = {} if !config
        config.outputFile = 'm/build.json' if !config.outputFile
        config.allowedExt = ['.jpeg', '.jpg', '.png', '.gif', '.svg'] if !config.allowedExt
        config.distDir = 'm/' if !config.distDir
        config.baseUrl = '/m/' if !config.baseUrl
        config.rootPath = __dirname if !config.rootPath
        config.maxFileSize = 4096 if !config.maxFileSize
        config.debug = false if !config.debug

        cache = new CacheFile tmp_dir: config.tmp

        clearDir(config.distDir)
        exclude_cs = [] # не удалять при очистке кеша

        for package_idx, package_content of config.packages
            res[package_idx] = []
            tags_tpl =
                css: "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\">"
                js: "<script type=\"text/javascript\" src=\"%s\"></script>"
            console.log "[#{package_idx}]" #, package_content
            # внешние скрипты
            for _type in ['css', 'js']
                _type_ext = "#{_type}_ext"
                if package_content[_type_ext]
                    for l in package_content[_type_ext]
                        part =
                            tag: util.format tags_tpl[_type], l
                            consists_of: [util.format tags_tpl[_type], l]
                        res[package_idx].push part
                        # console.log part
            # внутренние скрипты
            for _type in ['css', 'js']
                if package_content[_type]
                    consists_of = []
                    files = []
                    src = []

                    # нормализовать пути и паттерны к файлам
                    # console.log '_type', package_content[_type]
                    for l in package_content[_type]
                        if glob.hasMagic(l)
                            match = glob.sync "#{config.rootPath}/#{l}"
                            for mm in match
                                mm = path.normalize('/' + mm.replace(config.rootPath, ''))
                                if src.indexOf(mm) > -1
                                    continue
                                src.push mm
                        else
                            src.push l
                    # console.log 'files:', src

                    for l in src
                        consists_of.push util.format tags_tpl[_type], l
                        files.push path.normalize "#{config.rootPath}/#{l}"

                    # console.log package_idx, files, consists_of
                    src_real = src.map (p) ->
                        return path.normalize "#{config.rootPath}/#{p}"

                    cs = cache.checksum src_real
                    exclude_cs.push cs
                    if !(ugilified = cache.get(cs))
                        ugilified = uglify files, _type, config
                        cache.set cs, ugilified

                    distFile = crypto.createHash('md5').update(ugilified).digest('hex')[0...7] + '.' + _type
                    distFile = "#{package_idx}-#{distFile}"
                    dist = path.normalize path.join(config.distDir, distFile)
                    fs.writeFileSync(dist, ugilified, FILE_ENCODING)

                    url_uglified = path.normalize "#{config.baseUrl}/#{distFile}"

                    part =
                        tag: util.format tags_tpl[_type], url_uglified
                        consists_of: consists_of
                    res[package_idx].push part

        fs.writeFileSync config.outputFile, JSON.stringify(res, null, 4), FILE_ENCODING
        cache.audit(exclude_cs)
        return

if module.parent
    module.exports = plugin
else
    config = require './builder-config'
    # console.log config
    plugin.build config
    # console.log util.inspect(config, { showHidden: true, depth: null })
    # console.log (config.rootPath + '/phone/js/main.js').replace config.rootPath, ''
    # console.log util.format 'srcipt url="%s"', 'http://bilder.com'
    # console.log __dirname, path.relative __dirname + '/phone/js/main.js', __dirname

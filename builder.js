// Generated by CoffeeScript 1.10.0

/*
Version: 0.0.2
 */
'use strict';
var EOL, FILE_ENCODING, TMP_DIR, base64replace, clearDir, config, fs, glob, mime, path, plugin, uglify, util;

fs = require('fs');

path = require('path');

util = require('util');

mime = require('mime');

glob = require('glob');

TMP_DIR = '/tmp/';

FILE_ENCODING = 'utf-8';

EOL = "\n";

clearDir = function(dirPath, deleteRoot) {
  var e, error, filePath, files, i, j, len;
  if (deleteRoot == null) {
    deleteRoot = false;
  }
  try {
    files = fs.readdirSync(dirPath);
  } catch (error) {
    e = error;
    return;
  }
  if (files.length > 0) {
    for (j = 0, len = files.length; j < len; j++) {
      i = files[j];
      filePath = dirPath + "/" + i;
      if (fs.statSync(filePath).isFile()) {
        fs.unlinkSync(filePath);
      } else {
        clearDir(filePath);
      }
    }
  }
  if (deleteRoot) {
    fs.rmdirSync(dirPath, true);
  }
};

base64replace = function(src, config) {
  var out, rImages;
  if (!Array.isArray(src)) {
    src = [src];
  }
  rImages = /url(?:\(['|"]?)(.*?)(?:['|"]?\))(?!.*\/\*base64:skip\*\/)/ig;
  out = src.map(function(filePath) {
    var code, cssDir, files;
    console.log("\#\# CSS::" + filePath);
    files = {};
    code = fs.readFileSync(filePath, FILE_ENCODING);
    cssDir = path.dirname(filePath);
    return code.replace(rImages, function(match, file) {
      var base64, e, error, fileName, relativeFilePath, relativeMatch, size;
      if (match.indexOf('data:image') > -1) {
        return match;
      }
      relativeFilePath = path.normalize(path.relative(config.distDir, cssDir) + '/' + file);
      relativeMatch = "url(" + relativeFilePath + ")";
      if (config.allowedExt.indexOf(path.extname(file)) < 0) {
        return relativeMatch;
      }
      if (file.indexOf('/') === 0) {
        fileName = path.normalize(config.rootPath + "/" + file);
      } else {
        fileName = path.normalize(cssDir + "/" + file);
      }
      try {
        if (!fs.statSync(fileName).isFile()) {
          console.log("Skip " + fileName + " not is file");
          return match;
        }
      } catch (error) {
        e = error;
        console.log("Skip " + fileName + " does not exists");
        return match;
      }
      size = fs.statSync(fileName).size;
      if (size > config.maxFileSize) {
        console.log(("Skip " + fileName + " (") + (Math.round(size / 1024 * 100) / 100) + 'k)');
        return relativeMatch;
      } else {
        base64 = fs.readFileSync(fileName).toString('base64');
        files[fileName] = true;
        return "url(\"data:" + mime.lookup(file) + (";base64," + base64 + "\")");
      }
    });
  });
  return out.join(EOL);
};

uglify = function(src, type, config) {
  var code, comment, dist, distFile, ff, j, len, md5sum, mincode, uglifyCSS, uglifyJS;
  if (!Array.isArray(src)) {
    src = [src];
  }
  if (!config.distDir || !fs.lstatSync(config.distDir).isDirectory()) {
    throw new Error(config.distDir + " is not a directory");
  }
  md5sum = require('crypto').createHash('md5');
  code = '';
  switch (type) {
    case 'css':
      uglifyCSS = require('uglifycss');
      code = base64replace(src, config);
      code = uglifyCSS.processString(code);
      break;
    case 'js':
      uglifyJS = require('uglify-js');
      mincode = uglifyJS.minify(src, {
        compress: {
          hoist_funs: false
        }
      });
      code = mincode.code;
      break;
    default:
      throw new Error(type + " must bee js|css");
  }
  comment = "/**\n";
  for (j = 0, len = src.length; j < len; j++) {
    ff = src[j];
    ff = ff.replace(config.rootPath, '');
    comment += " * " + ff + "\n";
  }
  comment += " */";
  distFile = md5sum.update(code).digest('hex').slice(0, 7) + '.' + type;
  dist = path.normalize(config.distDir + '/' + distFile);
  fs.writeFileSync(dist, comment + "\n" + code, FILE_ENCODING);
  return path.normalize(config.baseUrl + "/" + distFile);
};

plugin = {
  build: function(config) {
    var _type, _type_ext, consists_of, files, j, k, l, len, len1, len2, len3, len4, len5, m, match, mm, n, o, p, package_content, package_idx, part, ref, ref1, ref2, ref3, ref4, res, src, tags_tpl, ugilified;
    res = {};
    if (!config) {
      config = {};
    }
    if (!config.outputFile) {
      config.outputFile = 'm/build.json';
    }
    if (!config.allowedExt) {
      config.allowedExt = ['.jpeg', '.jpg', '.png', '.gif', '.svg'];
    }
    if (!config.distDir) {
      config.distDir = 'm/';
    }
    if (!config.baseUrl) {
      config.baseUrl = '/m/';
    }
    if (!config.rootPath) {
      config.rootPath = __dirname;
    }
    if (!config.maxFileSize) {
      config.maxFileSize = 4096;
    }
    clearDir(config.distDir);
    ref = config.packages;
    for (package_idx in ref) {
      package_content = ref[package_idx];
      res[package_idx] = [];
      tags_tpl = {
        css: "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\">",
        js: "<script type=\"text/javascript\" src=\"%s\"></script>"
      };
      console.log("[" + package_idx + "]");
      ref1 = ['css', 'js'];
      for (j = 0, len = ref1.length; j < len; j++) {
        _type = ref1[j];
        _type_ext = _type + "_ext";
        if (package_content[_type_ext]) {
          ref2 = package_content[_type_ext];
          for (k = 0, len1 = ref2.length; k < len1; k++) {
            l = ref2[k];
            part = {
              tag: util.format(tags_tpl[_type], l),
              consists_of: [util.format(tags_tpl[_type], l)]
            };
            res[package_idx].push(part);
          }
        }
      }
      ref3 = ['css', 'js'];
      for (m = 0, len2 = ref3.length; m < len2; m++) {
        _type = ref3[m];
        if (package_content[_type]) {
          consists_of = [];
          files = [];
          src = [];
          ref4 = package_content[_type];
          for (n = 0, len3 = ref4.length; n < len3; n++) {
            l = ref4[n];
            if (glob.hasMagic(l)) {
              match = glob.sync(config.rootPath + "/" + l);
              for (o = 0, len4 = match.length; o < len4; o++) {
                mm = match[o];
                mm = path.normalize('/' + mm.replace(config.rootPath, ''));
                if (src.indexOf(mm) > -1) {
                  continue;
                }
                src.push(mm);
              }
            } else {
              src.push(l);
            }
          }
          for (p = 0, len5 = src.length; p < len5; p++) {
            l = src[p];
            consists_of.push(util.format(tags_tpl[_type], l));
            files.push(path.normalize(config.rootPath + "/" + l));
          }
          ugilified = uglify(files, _type, config);
          part = {
            tag: util.format(tags_tpl[_type], ugilified),
            consists_of: consists_of
          };
          res[package_idx].push(part);
        }
      }
    }
    fs.writeFileSync(config.outputFile, JSON.stringify(res, null, 4), FILE_ENCODING);
  }
};

if (module.parent) {
  module.exports = plugin;
} else {
  config = require('./builder-config');
  plugin.build(config);
}

// Generated by CoffeeScript 1.8.0

/*
Version: 0.0.2
 */
'use strict';
var EOL, FILE_ENCODING, TMP_DIR, base64replace, clearDir, config, fs, mime, path, plugin, uglify, util;

fs = require('fs');

path = require('path');

util = require('util');

mime = require('mime');

TMP_DIR = '/tmp/';

FILE_ENCODING = 'utf-8';

EOL = "\n";

clearDir = function(dirPath, deleteRoot) {
  var e, filePath, files, i, _i, _len;
  if (deleteRoot == null) {
    deleteRoot = false;
  }
  try {
    files = fs.readdirSync(dirPath);
  } catch (_error) {
    e = _error;
    return;
  }
  if (files.length > 0) {
    for (_i = 0, _len = files.length; _i < _len; _i++) {
      i = files[_i];
      filePath = "" + dirPath + "/" + i;
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
  var allowedExt, distDir, out, rImages, rootPath;
  allowedExt = config.allowedExt || ['.jpeg', '.jpg', '.png', '.gif', '.svg'];
  distDir = config.distDir || 'm/';
  rootPath = config.rootPath || __dirname;
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
      var base64, e, fileName, relativeFilePath, relativeMatch, size;
      if (match.indexOf('data:image') > -1) {
        return match;
      }
      relativeFilePath = path.normalize(path.relative(distDir, cssDir) + '/' + file);
      relativeMatch = "url(" + relativeFilePath + ")";
      if (allowedExt.indexOf(path.extname(file)) < 0) {
        return relativeMatch;
      }
      if (file.indexOf('/') === 0) {
        fileName = path.normalize("" + config.rootPath + "/" + file);
      } else {
        fileName = path.normalize("" + cssDir + "/" + file);
      }
      try {
        if (!fs.statSync(fileName).isFile()) {
          console.log("Skip " + fileName + " not is file");
          return match;
        }
      } catch (_error) {
        e = _error;
        console.log("Skip " + fileName + " does not exists");
        return match;
      }
      size = fs.statSync(fileName).size;
      if (size > 4096) {
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
  var baseUrl, code, comment, dist, distDir, distFile, ff, md5sum, mincode, rootPath, uglifyCSS, uglifyJS, _i, _len;
  if (!Array.isArray(src)) {
    src = [src];
  }
  distDir = config.distDir || 'm/';
  baseUrl = config.baseUrl || '/m/';
  rootPath = config.rootPath || __dirname;
  if (!distDir || !fs.lstatSync(distDir).isDirectory()) {
    throw new Error("" + distDir + " is not a directory");
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
      throw new Error("" + type + " must bee js|css");
  }
  comment = "/**\n";
  for (_i = 0, _len = src.length; _i < _len; _i++) {
    ff = src[_i];
    ff = ff.replace(rootPath, '');
    comment += " * " + ff + "\n";
  }
  comment += " */";
  distFile = md5sum.update(code).digest('hex').slice(0, 7) + '.' + type;
  dist = path.normalize(distDir + '/' + distFile);
  fs.writeFileSync(dist, "" + comment + "\n" + code, FILE_ENCODING);
  return path.normalize("" + baseUrl + "/" + distFile);
};

plugin = {
  build: function(config) {
    var consists_of, files, l, outputFile, package_content, package_idx, part, res, tags_tpl, ugilified, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3, _ref4, _type, _type_ext;
    res = {};
    outputFile = config.outputFile || 'm/build.json';
    clearDir(config.distDir);
    _ref = config.packages;
    for (package_idx in _ref) {
      package_content = _ref[package_idx];
      res[package_idx] = [];
      tags_tpl = {
        css: "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\">",
        js: "<script type=\"text/javascript\" src=\"%s\"></script>"
      };
      console.log("[" + package_idx + "]");
      _ref1 = ['css', 'js'];
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        _type = _ref1[_i];
        _type_ext = "" + _type + "_ext";
        if (package_content[_type_ext]) {
          _ref2 = package_content[_type_ext];
          for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
            l = _ref2[_j];
            part = {
              tag: util.format(tags_tpl[_type], l),
              consists_of: [util.format(tags_tpl[_type], l)]
            };
            res[package_idx].push(part);
          }
        }
      }
      _ref3 = ['css', 'js'];
      for (_k = 0, _len2 = _ref3.length; _k < _len2; _k++) {
        _type = _ref3[_k];
        if (package_content[_type]) {
          consists_of = [];
          files = [];
          _ref4 = package_content[_type];
          for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
            l = _ref4[_l];
            consists_of.push(util.format(tags_tpl[_type], l));
            files.push(path.normalize("" + config.rootPath + "/" + l));
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
    fs.writeFileSync(outputFile, JSON.stringify(res, null, 4), FILE_ENCODING);
  }
};

if (require.main === module) {
  config = require('./builder-config');
  plugin.build(config);
}

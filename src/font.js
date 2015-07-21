/* global require,module,process,console */
'use strict';

var fs = require('fs');
var path = require('path');
var Fontmin = require('fontmin');
var Promise = require('promise');

var TEMP = '.FONTSPIDER_TEMP';
var number = 0;


function Font (src, options) {
    
    number ++;

    var fontmin = new Fontmin().src(src);
    var dest = options.dest || {};
    var chars = options.chars;
    var extname = path.extname(src);
    var basename = path.basename(src, extname);
    var temp = TEMP + number;

    dest.ttf = dest.ttf || src;

    if (options.chars) {
        fontmin.use(Fontmin.glyph({
            text: chars
        }));
    }

    Object.keys(dest).forEach(function (key) {
        if (typeof Fontmin['ttf2' + key] === 'function') {
            fontmin.use(Fontmin['ttf2' + key]({clone: true}));
        }
    });


    fontmin.dest(temp);
    

    return new Promise(function (resolve, reject) {
        fontmin.run(function (err, files) {
            if (err) {
                reject(err);
            } else {

                Object.keys(dest).forEach(function (key) {

                    var filename = basename + '.' + key;

                    // 特殊逻辑，支持非ttf后缀的turetype字体
                    // if (key === 'ttf') {
                    //     filename = basename + extname;
                    // }

                    var file = path.join(temp, filename);
                    var out = dest[key];

                    file = path.resolve(file);
                    rename(file, out);
                });


                rmdir(temp);
                resolve(files);
            }
        });
    });
}


// 重命名文件或文件夹
function rename (src, target) {
    if (fs.existsSync(src)) {
        var dir = path.dirname(target);
        mkdir(dir);
        fs.renameSync(src, target);
    }
}


// 创建目录，包括子文件夹
function mkdir (dir) {

    var currPath = dir;
    var toMakeUpPath = [];

    while (!fs.existsSync(currPath)) {
        toMakeUpPath.unshift(currPath);
        currPath = path.dirname(currPath);
    }

    toMakeUpPath.forEach(function (pathItem) {
        fs.mkdirSync(pathItem);
    });
}


// 删除文件夹，包括子文件夹
function rmdir (dir) {

    var walk = function (dir) {

        if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
            return;
        }

        var files = fs.readdirSync(dir);

        if (!files.length) {
            fs.rmdirSync(dir);
            return;
        } else {
            files.forEach(function (file) {
                var fullName = path.join(dir, file);
                if (fs.statSync(fullName).isDirectory()) {
                    walk(fullName);
                } else {
                    fs.unlinkSync(fullName);
                }
            });
        }

        fs.rmdirSync(dir);
    };

    walk(dir);
}


module.exports = Font;

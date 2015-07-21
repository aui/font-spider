/* global require,module,process,console */
'use strict';

var fs = require('fs');
var path = require('path');
var util = require('util');
var events = require('events');

var Promise = require('promise');
var glob = require('glob');
var Font = require('./font');
var Spider = require('./spider');
var version = require('../package.json').version;
var color = require('./color');

// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;



var FontSpider = function (src, options) {

    if (typeof src === 'string') {
        src = glob.sync(src);
    } else if( Array.isArray(src) ) {
        var srcs = [];
        src.forEach(function (item) {
            srcs = srcs.concat(glob.sync(item));
        });
        src = srcs;
    }

    options = options || {};
    for (var key in FontSpider.defaults) {
        if (options[key] === undefined) {
            options[key] = FontSpider.defaults[key];
        }
    }

    this.src = src;
    this.options = options;

    return this._start();
};


FontSpider.Font = Font;
FontSpider.Spider = Spider;
FontSpider.defaults = Object.create(Spider.defaults);
FontSpider.defaults.backup = true;

FontSpider.defaults.resourceBeforeLoad = function (file) {
    writeln('Loading ..', color('cyan', file));
};

FontSpider.defaults.resourceError = function (file) {
    writeln('');
};

FontSpider.prototype = {

    constructor: FontSpider,


    _start: function () {

        var that = this;
        var src = this.src;
        var options = this.options;
        var backup = options.backup !== false;

        writeln('Loading ..');


        return new Spider(src, options)
        .then(function (data) {

            writeln('Loading ..');
            var result = data.map(function (item) {

                var source;
                var chars = item.chars;


                // 如果没有使用任何字符，则不处理字体
                if (!chars) {
                    return;
                }


                // 找 .ttf 的字体文件
                item.files.forEach(function (file) {
                    var extname = path.extname(file).toLocaleLowerCase();

                    if (RE_SERVER.test(file)) {
                        throw new Error('does not support the absolute path "' + file + '"'); 
                    } else if (extname === '.ttf') {
                        source = file;
                    }

                });


                // 必须有 TTF 字体
                if (!source) {
                    throw new Error('"' + item.name  + '"' + ' did not find turetype fonts');
                }



                var dirname = path.dirname(source);
                var basename = path.basename(source);
                var extname = path.extname(source);
                var backupFile;


                // 备份字体
                if (backup) {

                    // version < 0.2.1
                    if (fs.existsSync(source + '.backup')) {
                        backupFile = source + '.backup';
                    } else {
                        backupFile = dirname + '/.font-spider/' + basename;
                    }

                    if (fs.existsSync(backupFile)) {
                        copyFile(backupFile, source);
                    } else {
                        copyFile(source, backupFile);
                    }

                }



                if (!fs.existsSync(source)) {
                    throw new Error('"' + source + '" file not found');
                }


                var stat = fs.statSync(source);
                var destConfig = {};


                item.files.forEach(function (file) {

                    var extname = path.extname(file).toLocaleLowerCase();
                    var type = extname.replace('.', '');

                    destConfig[type] = file;

                });



                return new Font(source, {
                    dest: destConfig,
                    chars: chars
                }).then(function (data) {

                    writeln('');

                    write('Font name:', color('cyan', item.name));
                    write('Original size:', color('green', stat.size / 100 + ' KB'));
                    write('Include chars:', chars);

                    item.files.forEach(function (file) {
                        if (fs.existsSync(file)) {
                            write('File', color('cyan', path.relative('./', file)),
                                'created:', color('cyan', + fs.statSync(file).size / 1000 + ' KB'));
                        }
                    });

                    write('');

                    return data;
                });

            });


            return Promise.all(result);
        })
        .catch(function (errors) {
            writeln('');
            write(color('red', errors.stack.toString()));
            return Promise.reject(errors);
        });

    }
};



function copyFile (srcpath, destpath) {
    var destdir = path.dirname(destpath);
    var contents = fs.readFileSync(srcpath);
    mkdir(destdir);
    fs.writeFileSync(destpath, contents);
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


function writeln () {
    var stream = process.stdout;

    if (!stream.isTTY) {
        return;
    }

    stream.clearLine();
    stream.cursorTo(0);
    stream.write(Array.prototype.join.call(arguments, ' '));
}



function write () {
    var stream = process.stdout;

    if (!stream.isTTY) {
        return;
    }

    stream.write(Array.prototype.join.call(arguments, ' ') + '\n');
}


module.exports = FontSpider;

'use strict';

var fs = require('fs');
var path = require('path');
var util = require('util');
var events = require('events');

var Promise = require('promise');
var glob = require('glob');
var Font = require('./font.js');
var Spider = require('./spider.js');
var ColorConsole = require('./color-console.js');
var version = require('../package.json').version;

// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;



var copyFile = function (srcpath, destpath) {
    var destdir = path.dirname(destpath);
    var contents = fs.readFileSync(srcpath);
    mkdir(destdir);
    fs.writeFileSync(destpath, contents);
};


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
};



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

    new ColorConsole(options).mix(this);

    return this._start();
};


FontSpider.Font = Font;
FontSpider.Spider = Spider;
FontSpider.defaults = Object.create(Spider.defaults);
FontSpider.defaults.backup = true;


FontSpider.prototype = {

    constructor: FontSpider,


    _start: function () {

        var that = this;
        var src = this.src;
        var options = this.options;
        var backup = options.backup !== false;

        return new Spider(src, options)
        .then(function (data) {

            var result = [];

            data.forEach(function (item) {

                
                var error;
                var source;
                var chars = item.chars;


                // 如果没有使用任何字符，则不处理字体
                if (!chars) {
                    return;
                }

                // 找到 .ttf 的字体文件
                item.files.forEach(function (file) {
                    var extname = path.extname(file).toLocaleLowerCase();

                    if (RE_SERVER.test(file)) {
                        error = 'does not support the absolute path "' + file + '"';
                        that.error('[ERROR]', error);
                    } else if (extname === '.ttf') {
                        source = file;
                    }

                });


                if (error) {
                    return;
                }


                if (!source) {
                    error = '"' + item.name  + '"' + ' did not find turetype fonts';
                    that.error('[ERROR]', error);
                    return;
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
                    error = '"' + source + '" file not found';
                    that.error('[ERROR]', error);
                    return;
                }



                var stat = fs.statSync(source);
                var destConfig = {};


                item.files.forEach(function (file) {

                    var extname = path.extname(file).toLocaleLowerCase();
                    var type = extname.replace('.', '');

                    destConfig[type] = file;

                });

                result.push(new Font(source, {
                    dest: destConfig,
                    chars: chars
                }).then(function () {

                    that.info('Font name:', '(' + item.name + ')');
                    that.info('Original size:', '<' + stat.size / 100 + ' KB>');
                    that.info('Include chars:', chars);

                    item.files.forEach(function (file) {
                        if (fs.existsSync(file)) {
                            that.info('File', '(' + path.relative('./', file) + ')',
                                'created:', '<' + fs.statSync(file).size / 1000 + ' KB>');    
                        }
                    });

                    that.info('');

                }));

            });

            return Promise.all(result);
        })
        .then(null, function (errors) {
            that.error('[ERROR]', errors && errors.stack || errors);
        });

    }
};


module.exports = FontSpider;

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

// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;



var copyFile = function (srcpath, destpath) {
    var contents = fs.readFileSync(srcpath);
    fs.writeFileSync(destpath, contents);
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
FontSpider.BACKUP_EXTNAME = '.backup';
FontSpider.defaults = Object.create(Spider.defaults);
FontSpider.defaults.backup = true;


FontSpider.prototype = {

    constructor: FontSpider,


    _start: function () {

        var that = this;
        var src = this.src;
        var options = this.options;
        var backup = options.backup !== false;

        var BACKUP_EXTNAME = FontSpider.BACKUP_EXTNAME;


        return new Spider(src, options)
        .then(function (data) {

            var result = [];

            data.forEach(function (item) {

                var chars = item.chars;
                var error;


                // 如果没有使用任何字符，则不处理字体
                if (!chars) {
                    return;
                }


                // 找到 .ttf 的字体文件
                var src, dest;
                item.files.forEach(function (file) {
                    var extname = path.extname(file).toLocaleLowerCase();

                    if (error) {
                        return;
                    }

                    if (RE_SERVER.test(file)) {
                        error = new Error('Error: does not support the absolute path "' + file + '"');
                        that.error('[ERROR]', error);
                        return;
                    }

                    if (extname !== '.ttf') {
                        return;
                    }

                    if (fs.existsSync(file)) {

                        if (backup && fs.existsSync(file + BACKUP_EXTNAME)) {
                            // 使用备份的字体
                            src = file + BACKUP_EXTNAME;
                        } else {
                            src = file;
                            // 备份字体，这样可以反复处理
                            backup && copyFile(src, src + BACKUP_EXTNAME);
                        }

                        dest = file;
                    } else {

                        error = new Error('"' + file + '" file not found');
                        that.error('[ERROR]', error);
                    }


                });


                if (error) {
                    return;
                }


                if (!src) {
                    error = new Error('"' + item.name  + '"' + ' did not find turetype fonts');
                    that.error('[ERROR]', error);
                    return;
                }


                dest = dest || src;
                var dirname = path.dirname(dest);
                var extname = path.extname(dest);
                var basename = path.basename(dest, extname);
                var out = path.join(dirname, basename);
                var stat = fs.statSync(src);


                var destConfig = {};

                item.files.forEach(function (file) {

                    var extname = path.extname(file).toLocaleLowerCase();
                    var type = extname.replace('.', '');

                    destConfig[type] = file;

                });

                result.push(new Font(src, {
                    dest: destConfig,
                    chars: chars
                }).then(function () {

                    that.info('Font name:', '(' + item.name + ')');
                    that.info('Original size:', '<' + stat.size / 100 + ' KB>');
                    that.info('Include chars:', chars);

                    item.files.forEach(function (file) {
                        that.info('File', '(' + path.relative('./', file) + ')',
                            'created:', '<' + fs.statSync(file).size / 1000 + ' KB>');
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

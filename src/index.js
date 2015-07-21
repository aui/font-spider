/* global require,module,process,console */
'use strict';

var fs = require('fs');
var path = require('path');

var Promise = require('promise');
var glob = require('glob');
var Font = require('./font');
var Spider = require('./spider');
var version = require('../package.json').version;

var utils = require('./utils');
var color = utils.color;

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


FontSpider.defaults = {
    backup: true
};



FontSpider.prototype = {

    constructor: FontSpider,


    _start: function () {

        var that = this;
        var src = this.src;
        var options = this.options;
        var backup = options.backup !== false;


        return new Spider(src, options).then(function (data) {

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
                        utils.copyFile(backupFile, source);
                    } else {
                        utils.copyFile(source, backupFile);
                    }

                }



                if (!fs.existsSync(source)) {
                    throw new Error('"' + source + '" file not found');
                }


                var originalSize = fs.statSync(source).size;
                var destConfig = {};


                item.files.forEach(function (file) {

                    var extname = path.extname(file).toLocaleLowerCase();
                    var type = extname.replace('.', '');

                    destConfig[type] = file;

                });

                
                // 记录原始文件大小
                item.originalSize = originalSize;


                // 压缩字体
                return new Font(source, {
                    dest: destConfig,
                    chars: chars
                }).then(function () {
                    return item;
                });

            });


            return Promise.all(result);
        });

    }
};



module.exports = FontSpider;

/* global require,module */

'use strict';

var fs = require('fs');
var path = require('path');
var Fontmin = require('fontmin');
var Promise = require('promise');
var utils = require('./utils');


// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;

var TEMP = '.FONT_SPIDER_TEMP';
var number = 0;



function Compress (webFont, options) {

    return new Promise(function (resolve, reject) {


        if (webFont.length === 0) {
            resolve(webFont);
            return;
        }


        number ++;
        options = getOptions(options);


        var files = {};
        var source;
        

        webFont.files.forEach(function (file) {
            var extname = path.extname(file);
            var type = extname.replace('.', '');

            if (RE_SERVER.test(file)) {
                throw new Error('does not support remote path "' + file + '"'); 
            }

            if (type.toLocaleLowerCase() === 'ttf') {
                source = file;
            }

            files[type] = file;
        });



        // 必须有 TTF 字体
        if (!source) {
            throw new Error('"' + webFont.name + '"' + ' did not find turetype fonts');
        }



        this.source = source;
        this.webFont = webFont;
        this.options = options;
        this.files = files;
        this.dirname = path.dirname(source);
        this.extname = path.extname(source);
        this.basename = path.basename(source, this.extname);


        // 备份字体与恢复备份
        if (options.backup) {
            this.backup();
        }

        if (!fs.existsSync(this.source)) {
            throw new Error('"' + source + '" file not found');
        }

        this.min(resolve, reject);
    }.bind(this));
}


Compress.defaults = {
    backup: true
};


Compress.prototype = {



    // 字体恢复与备份
    backup: function () {

        var backupFile;

        var source = this.source;
        var dirname = this.dirname;
        var basename = this.basename;

        // version < 0.2.1
        if (fs.existsSync(source + '.backup')) {
            backupFile = source + '.backup';
        } else {
            backupFile = path.join(dirname, '.font-spider', basename);
        }

        if (fs.existsSync(backupFile)) {
            utils.cp(backupFile, source);
        } else {
            utils.cp(source, backupFile);
        }
    },



    min: function (succeed, error) {

        var webFont = this.webFont;
        var files = this.files;
        var source = this.source;
        var dirname = this.dirname;
        var basename = this.basename;

        var originalSize = fs.statSync(source).size;


        var fontmin = new Fontmin().src(source);
        var temp = path.join(dirname, TEMP + number);

        // 有些 webfont 使用 content 属性加字体继承，查询不到 chars
        // 不压缩，避免意外将 fonticon 干掉了
        if (webFont.chars) {
            fontmin.use(Fontmin.glyph({
                text: webFont.chars
            }));
        }


        Object.keys(files).forEach(function (key) {
            key = key.toLocaleLowerCase();
            if (typeof Fontmin['ttf2' + key] === 'function') {
                fontmin.use(Fontmin['ttf2' + key]({clone: true}));
            }
        });


        fontmin.dest(temp);

        fontmin.run(function (errors /*, buffer*/) {

            if (errors) {
                error(errors);
            } else {
                
                Object.keys(files).forEach(function (key) {

                    var filename = basename + '.' + key;

                    var file = path.join(temp, filename);
                    var out = files[key];

                    file = path.resolve(file);
                    utils.rename(file, out);
                });


                utils.rmdir(temp);

                // 添加新字段：记录原始文件大小
                webFont.originalSize = originalSize;

                succeed(webFont);
            }
        });
    }
};



function getOptions (options) {
    var config = Object.create(Compress.defaults);
    for (var key in options) {
        config[key] = options[key];
    }
    return config;
}


module.exports = Compress;

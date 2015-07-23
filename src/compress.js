/* global require,module */

'use strict';

var fs = require('fs');
var path = require('path');
var Fontmin = require('fontmin');
var Promise = require('promise');
var fsUtils = require('./fs-utils');


// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;

var TEMP = '.FONT_SPIDER_TEMP';
var number = 0;



function Compress (data, options) {

    number ++;
    options = getOptions(options);

    var files = {};
    var source;
    

    data.files.forEach(function (file) {
        var extname = path.extname(file).toLocaleLowerCase();
        var type = extname.replace('.', '');

        if (RE_SERVER.test(file)) {
            throw new Error('does not support the absolute path "' + file + '"'); 
        }

        if (type === 'ttf') {
            source = file;
        }

        files[type] = file;
    });



    // 必须有 TTF 字体
    if (!source) {
        throw new Error('"' + data.name + '"' + ' did not find turetype fonts');
    }



    this.source = source;
    this.data = data;
    this.options = options;
    this.files = files;
    this.dirname = path.dirname(source);
    this.extname = path.extname(source);
    this.basename = path.basename(source, this.extname);


    // 备份字体与恢复备份
    if (options.backup) {
        this.backup();
    }


    if (!fs.existsSync(source)) {
        throw new Error('"' + source + '" file not found');
    }


    return this.min();
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
            backupFile = dirname + '/.font-spider/' + basename;
        }

        if (fs.existsSync(backupFile)) {
            fsUtils.cp(backupFile, source);
        } else {
            fsUtils.cp(source, backupFile);
        }
    },

    min: function () {

        var data = this.data;
        var files = this.files;
        var source = this.source;
        var dirname = this.dirname;
        var basename = this.basename;
        var originalSize = fs.statSync(source).size;

        var fontmin = new Fontmin().src(source);
        var temp = path.join(dirname, TEMP + number);


        if (data.chars) {
            fontmin.use(Fontmin.glyph({
                text: data.chars
            }));
        }



        Object.keys(files).forEach(function (key) {
            if (typeof Fontmin['ttf2' + key] === 'function') {
                fontmin.use(Fontmin['ttf2' + key]({clone: true}));
            }
        });


        fontmin.dest(temp);
        

        return new Promise(function (resolve, reject) {
            fontmin.run(function (errors /*, buffer*/) {

                if (errors) {
                    reject(errors);
                } else {

                    Object.keys(files).forEach(function (key) {

                        var filename = basename + '.' + key;

                        var file = path.join(temp, filename);
                        var out = files[key];

                        file = path.resolve(file);
                        fsUtils.rename(file, out);
                    });


                    fsUtils.rmdir(temp);

                    // 添加新字段：记录原始文件大小
                    data.originalSize = originalSize;

                    resolve(data);
                }
            });
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

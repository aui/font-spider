'use strict';

var fs = require('fs');
var path = require('path');
var gulp = require('gulp');
var Fontmin = require('fontmin');
var Adapter = require('../adapter');
var rename = require('gulp-rename');
var ttf2woff2 = require('gulp-ttf2woff2');


// http://font-spider.org/css/style.css
// var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^https?\:/i;

// @see https://github.com/ecomfe/fontmin/issues/30
if (typeof Fontmin.ttf2woff2 !== 'function') {
    Fontmin.ttf2woff2 = ttf2woff2;
}


function Compress(webFont, options) {
    options = new Adapter(options);
    return new Promise(function(resolve, reject) {

        if (webFont.length === 0) {
            resolve(webFont);
            return;
        }


        var sources = {};
        var sourceFormat = ['truetype', 'opentype'];


        webFont.files.forEach(function(file) {
            if (RE_SERVER.test(file.url)) {
                throw new Error('does not support remote path "' + file.url + '"');
            }

            if (sourceFormat.indexOf(file.format) !== -1) {
                sources[file.format] = file;
            }
        });



        this.source = sources.truetype || sources.opentype;
        this.webFont = webFont;
        this.options = options;


        if (!this.source) {
            throw new Error('"' + webFont.family + '"' + ' did not find truetype or opentype fonts');
        }


        // 备份字体与恢复备份
        this.backup(function(errors) {
            if (errors) {
                done(errors);
            } else {
                this.min(done);
            }
        }.bind(this));



        function done(errors, webFont) {
            if (errors) {
                reject(errors);
            } else {
                resolve(webFont);
            }
        }


    }.bind(this));
}


Compress.defaults = {
    backup: true
};


Compress.prototype = {
    constructor: Compress,


    // 字体恢复与备份
    backup: function(callback) {


        if (!this.options.backup) {
            return callback();
        }

        var source = this.source;
        var dirname = path.dirname(source.url);
        var basename = path.basename(source.url);
        var backupDir = path.join(dirname, '.font-spider');
        var backupFile = path.join(backupDir, basename);


        if (!fs.existsSync(backupFile)) {
            // version < 1.3.0
            backupFile = backupFile.replace(/\.[^\.]+$/, '');
            if (!fs.existsSync(backupFile)) {
                backupFile = null;
            }
        }

        if (backupFile) {
            // 恢复文件
            return gulp.src(backupFile).pipe(gulp.dest(dirname)).on('end', callback);
        } else {
            // 备份文件
            return gulp.src(source.url).pipe(gulp.dest(backupDir)).on('end', callback);
        }
    },

    min: function(callback) {

        var webFont = this.webFont;
        var source = this.source;
        var dirname = path.dirname(source.url);


        if (!fs.existsSync(source.url)) {
            return callback(new Error('"' + source.url + '" file not found'));
        }

        var originalSize = fs.statSync(source.url).size;
        var fontmin = new Fontmin().src(source.url);
        var paths = {};
        var types = {
            'embedded-opentype': 'ttf2eot',
            'woff': 'ttf2woff',
            'woff2': 'ttf2woff2',
            'svg': 'ttf2svg'
        };


        fontmin.use(Fontmin.glyph({
            trim: false,
            text: webFont.chars || '#' // 传入任意字符避免 fontmin@0.9.5 BUG
        }));


        if (source.format === 'opentype') {
            fontmin.use(Fontmin.otf2ttf());
        }


        webFont.files.forEach(function(file) {
            var format = file.format;
            var fn = types[format];
            var extname = path.extname(file.url);
            var basename = path.basename(file.url, extname);
            var relative = path.relative(dirname, file.url);

            paths[extname] = {
                file: file,
                dirname: path.dirname(relative),
                basename: basename,
                extname: extname
            };

            if (format === source.format) {
                return;
            }

            if (typeof Fontmin[fn] === 'function') {
                fontmin.use(Fontmin[fn]({
                    clone: true
                }));
            } else {
                throw new TypeError('compressing the ' + format + ' format fonts is not supported, ' +
                    'please delete it in the CSS file: "' + file.url + '"');
            }
        });


        fontmin.use(rename(function(path) {
            var newName = paths[path.extname];
            path.dirname = newName.dirname;
            path.basename = newName.basename;
            path.extname = newName.extname;
        }));


        fontmin.dest(dirname);
        fontmin.run(function(errors, buffer) {

            if (errors) {
                callback(errors);
            } else {

                buffer.forEach(function(buffer) {
                    paths[buffer.extname].file.size = buffer.contents.length;
                });

                // 添加新字段：记录原始文件大小
                webFont.originalSize = originalSize;

                callback(null, webFont);
            }
        });
    }

};


/**
 * 压缩字体
 * @param   {Array<WebFont>}    `WebFonts` 描述信息 @see ../spider/web-font.js
 * @param   {Adapter}           选项
 * @param   {Function}          回调函数
 * @return  {Promise}           如果没有 `callback` 参数则返回 `Promise` 对象
 */
module.exports = function(webFonts, adapter, callback) {
    adapter = new Adapter(adapter);

    if (!Array.isArray(webFonts)) {
        webFonts = [webFonts];
    }

    webFonts = Promise.all(webFonts.map(function(webFont) {
        return new Compress(webFont, adapter);
    }));


    if (typeof callback === 'function') {
        webFonts.then(function(webFonts) {
            process.nextTick(function() {
                callback(null, webFonts);
            });
            return webFonts;
        }).catch(function(errors) {
            process.nextTick(function() {
                callback(errors);
            });
            return Promise.reject(errors);
        });
    } else {
        return webFonts;
    }

};
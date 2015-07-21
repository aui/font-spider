/* global require,module,process,console */
'use strict';

var fs = require('fs');
var path = require('path');
var Fontmin = require('fontmin');
var Promise = require('promise');
var utils = require('./utils');

var TEMP = '.FONTSPIDER_TEMP';
var number = 0;


function Font (src, options) {
    
    number ++;

    var fontmin = new Fontmin().src(src);
    var dest = options.dest || {};
    var chars = options.chars;
    var dirname = path.dirname(src);
    var extname = path.extname(src);
    var basename = path.basename(src, extname);
    var temp = path.join(dirname, TEMP + number);

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
                    utils.rename(file, out);
                });


                utils.rmdir(temp);
                resolve(files);
            }
        });
    });
}





module.exports = Font;

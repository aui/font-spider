/* global require,module */

'use strict';

var path = require('path');
var Fontmin = require('fontmin');
var Promise = require('promise');
var fsUtils = require('./fs-utils');

var TEMP = '.FONT_SPIDER_TEMP';
var number = 0;


function Font (src, options) {
    
    number ++;

    var fontmin = new Fontmin().src(src);
    var dest = options.dest || {};
    var chars = options.chars;
    var dirname = path.dirname(src);
    var extname = path.extname(src);

    dest.ttf = dest.ttf || src;

    var basename = path.basename(dest.ttf, extname);
    var temp = path.join(dirname, TEMP + number);

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

                    var file = path.join(temp, filename);
                    var out = dest[key];

                    file = path.resolve(file);
                    fsUtils.rename(file, out);
                });


                fsUtils.rmdir(temp);
                resolve(files);
            }
        });
    });
}


module.exports = Font;

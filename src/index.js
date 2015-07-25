/* global require,module */

'use strict';

var glob = require('glob');
var Promise = require('promise');
var Spider = require('./spider');
var Compress = require('./compress');

var FontSpider = function (htmlFiles, options) {

    if (typeof htmlFiles === 'string') {
        htmlFiles = glob.sync(htmlFiles);
    } else if (Array.isArray(htmlFiles)) {
        var srcs = [];
        htmlFiles.forEach(function (item) {
            srcs = srcs.concat(glob.sync(item));
        });
        htmlFiles = srcs;
    }

    return new FontSpider.Spider(htmlFiles, options)
    .then(function (webFonts) {
        return Promise
        .all(webFonts.map(function (webFont) {
            return new FontSpider.Compress(webFont, options);
        }));
    });
};



FontSpider.Spider = Spider;
FontSpider.Compress = Compress;

FontSpider.defaults = {};
mix(FontSpider.defaults, Spider.defaults);
mix(FontSpider.defaults, Compress.defaults);

function mix (target, object) {
    Object.keys(object).forEach(function (key) {
        target[key] = object[key];
    });
}


module.exports = FontSpider;

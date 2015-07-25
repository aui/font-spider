/* global require,module */

'use strict';

var Promise = require('promise');
var Spider = require('./spider');
var Compress = require('./compress');

var FontSpider = function (htmlFiles, options) {
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

/* global require,module */

'use strict';

var glob = require('glob');
var Promise = require('promise');
var Spider = require('./spider');
var Compress = require('./compress');

var FontSpider = function (src, options) {

    if (typeof src === 'string') {
        src = glob.sync(src);
    } else if (Array.isArray(src)) {
        var srcs = [];
        src.forEach(function (item) {
            srcs = srcs.concat(glob.sync(item));
        });
        src = srcs;
    }

    return new FontSpider.Spider(src, options)
    .then(function (data) {
        return Promise
        .all(data.map(function (item) {
            return new FontSpider.Compress(item, options);
        }));
    });
};



FontSpider.Compress = Compress;
FontSpider.Spider = Spider;



module.exports = FontSpider;

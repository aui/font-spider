/* global require,module */

'use strict';

var Promise = require('promise');
var glob = require('glob');
var Font = require('./font');
var Spider = require('./spider');

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

    options = options || {};

    for (var key in FontSpider.defaults) {
        if (options[key] === undefined) {
            options[key] = FontSpider.defaults[key];
        }
    }

    return new Spider(src, options)
    .then(function (data) {
        return Promise
        .all(data.map(function (item) {
            return new Font(item, options);
        }));
    });
};



FontSpider.Font = Font;
FontSpider.Spider = Spider;
FontSpider.defaults = {
    backup: true
};


module.exports = FontSpider;

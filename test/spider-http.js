'use strict';

var Spider = require('../').Spider;
new Spider(['http://www.apple.com/cn/macbook/']).then(function (data) {
    console.info(data);
});


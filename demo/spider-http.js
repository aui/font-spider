'use strict';

var Spider = require('../').Spider;
new Spider(['http://www.apple.com/cn/macbook/']).then(function (data) {
    console.info(data);
    console.info('test end');
}, function (error) {
    console.error(error.message);
});


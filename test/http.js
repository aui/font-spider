'use strict';

var Spider = require('../').Spider;


var fontspider = new Spider(['http://www.apple.com/cn/iphone-6/'], {
    map: [],
    debug: true
});


fontspider.then(function (data) {
    console.log(data);
});




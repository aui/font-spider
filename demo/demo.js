'use strict';

var FontSpider = require('../');


var fontspider = new FontSpider([__dirname + '/*.html'], {
	map: [
		['http://test.com/css', __dirname + '/css']
	],
    ignore: ['FZXiaoZhuanTi-S13T.svg', '*.bk.css']
}).then(function () {
    console.info('test end');
});

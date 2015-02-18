'use strict';

var FontSpider = require('../');


var fontspider = new FontSpider([__dirname + '/*.html'], {
	map: [
		['http://test.com/css', __dirname + '/css']
	],
    ignore: ['FZXiaoZhuanTi-S13T.svg', '*.bk.css'],
    debug: true
});

fontspider.onoutput = function (data) {
    console.log('Font name: ' + (data.fontName));
    console.log('Original size: ' + (data.originalSize / 1000 + ' KB'));
    console.log('Include chars: ' + data.includeChars);
    data.output.forEach(function (item) {
        console.log('File ' + (item.file) + ' created: ' + (item.size / 1000 + ' kB'));
    });
    console.log('');
};

fontspider.onend = function () {};
fontspider.onerror = function (e) {
    console.error((e.message));
    if (e.result) {
        console.error(e.result);
    }
}

fontspider.start();
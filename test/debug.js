var assert = require("assert");
var path = require('path');

var utils = require('../src/spider/utils');
var Resource = require('../src/spider/resource');
var CssParser = require('../src/spider/css-parser');
var HtmlParser = require('../src/spider/html-parser');
var FontSpider = require('../');


new FontSpider.Spider(['http://www.apple.com/cn/macbook/'], {
    ignore: ['*family=PingHei*', '*family=Myriad*'],
    resourceBeforeLoad: function (file) {

        var REG_APPLE = /^https?\:\/\/(?:\w+\.)?apple\.com/;
        if (!REG_APPLE.test(file)) {
            throw new Error('只允许来自 Apple 网站的请求');
        }

        console.log('loading..', file);

    }
}).then(function (data) {
    console.log(data);
    console.log('test end');
}, function (error) {
    console.error(error.message);
});



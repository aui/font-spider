var assert = require("assert");
var path = require('path');

var utils = require('../src/spider/utils');
var Resource = require('../src/spider/resource');
var CssParser = require('../src/spider/css-parser');
var HtmlParser = require('../src/spider/html-parser');
var Spider = require('../src/spider/main');


function renderLine (str) {
    var stream = process.stdout;

    if (!stream.isTTY) {
        return
    };

    stream.clearLine();
    stream.cursorTo(0);
    stream.write(String(str));
};


new CssParser(new Resource(__dirname + '/css/loop.css')).then(function (data) {
    console.log(data);
}, function (errors) {
    console.log(errors.message)
});



var Spider = require('../').Spider;


new Spider(['http://www.apple.com/cn/macbook/'], {
    //onload: renderLine
}).then(function (data) {
    //console.info(data);
    //renderLine('\n');
    console.info('test end');
}, function (error) {
    console.error(error.message);
});

// new Spider([__dirname + '/html/error.html'], {
//     onload: console.log
// }).then(function (data) {
//     console.info(data);
//     console.info('test end');
// }, function (error) {
//     console.error(error.message);
// });


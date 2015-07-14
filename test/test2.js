var assert = require("assert");
var path = require('path');

var utils = require('../src/spider/utils');
var Resource = require('../src/spider/resource');
var CssParser = require('../src/spider/css-parser');
var HtmlParser = require('../src/spider/html-parser');
var Spider = require('../src/spider/main');

new Resource(__dirname + '/html/index.html').then(function (resource) {

    
    
    var htmlParser = new HtmlParser(resource);

    try {
    var cssFiles = htmlParser.getCssFiles();
    } catch(e) {
        console.log(e.stack)
    }
    console.log(cssFiles)

    
}, function (error) {
    console.error(error);
}); 

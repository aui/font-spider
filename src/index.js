'use strict';


var spider = require('./spider');
var concat = require('./concat');
var compressor = require('./compressor');
var Adapter = require('./adapter');

// TODO test
function runner(htmlFiles, options, callback) {

    if (!Array.isArray(htmlFiles)) {
        htmlFiles = [htmlFiles];
    }

    options = new Adapter(options);
    callback = callback || function() {};

    // 查找 webFont
    return Promise.all(htmlFiles.map(function(htmlFile) {
        return spider(htmlFile, options);
    // 合并 webFont
    })).then(function(webFonts) {
        return concat(webFonts, options);
    // 压缩 webFont
    }).then(function(webFonts) {
        return Promise.all(webFonts.map(function(webFont) {
            return compressor(webFont, options);
        }));
    }).then(function(webFonts) {
        process.nextTick(function() {
            callback(null, webFonts);
        });
        return webFonts;
    }).catch(function(errors) {
        process.nextTick(function() {
            callback(errors);
        });
        return Promise.reject(errors);
    });
}


runner.spider = spider;
runner.concat = concat;
runner.compressor = compressor;

module.exports = runner;
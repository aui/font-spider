'use strict';


var spider = require('./spider');
var compressor = require('./compressor');
var Adapter = require('./adapter');

/**
 * 分析并压缩字体
 * @param   {Array<String>}
 * @param   {Adapter}
 * @param   {Function}
 * @return  {Promise}
 */
function runner(htmlFiles, options, callback) {

    options = new Adapter(options);
    callback = callback || function() {};

    return spider(htmlFiles, options).then(function(webFonts) {
        return compressor(webFonts, options);
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
runner.compressor = compressor;

module.exports = runner;
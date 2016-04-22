'use strict';


var spider = require('./spider');
var compressor = require('./compressor');
var Adapter = require('./adapter');

/**
 * 分析并压缩字体
 * @param   {Array<String>}     网页路径列表
 * @param   {Adapter}           选项
 * @param   {Function}          回调函数
 * @return  {Promise}           如果没有 `callback` 参数则返回 `Promise` 对象
 */
function runner(htmlFiles, options, callback) {

    options = new Adapter(options);

    var webFonts = spider(htmlFiles, options).then(function(webFonts) {
        return compressor(webFonts, options);
    });


    if (typeof callback === 'function') {
        webFonts.then(function(webFonts) {
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
    } else {
        return webFonts;
    }
}


runner.spider = spider;
runner.compressor = compressor;

module.exports = runner;
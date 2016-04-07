'use strict';

var browser = require('browser-x');
var Adapter = require('../adapter');
var FontSpider = require('./font-spider');


// 扁平化二维数组
function reduce(array) {
    var ret = [];

    array.forEach(function(item) {
        ret.push.apply(ret, item);
    });

    return ret;
}



function sort(a, b) {
    return a.charCodeAt() - b.charCodeAt();
}



function unique(array) {
    var ret = [];

    array.forEach(function(val) {
        if (ret.indexOf(val) === -1) {
            ret.push(val);
        }
    });

    return ret;
}


function fontSpiderRunner(htmlFiles, options, callback) {

    if (!Array.isArray(htmlFiles)) {
        htmlFiles = [htmlFiles];
    }

    options = new Adapter(options);
    callback = callback || function() {};

    var queue = htmlFiles.map(function(htmlFile) {
        return browser.open(htmlFile, options).then(function(window) {
            return new FontSpider(window);
        });
    });


    return Promise.all(queue).then(function(webFonts) {

        webFonts = reduce(webFonts);

        var list = [];
        var indexs = {};


        // 合并相同 font-face
        webFonts.forEach(function(webFont) {
            var id = webFont.id;
            if (typeof indexs[id] === 'number') {
                var item = list[indexs[id]];
                item.chars += webFont.chars;
                item.selectors = item.selectors.concat(webFont.selectors);
            } else {
                indexs[id] = list.length;
                list.push(webFont);
            }
        });


        list.forEach(function(font) {
            var chars = font.chars.split('');

            // 对字符进行除重操作
            if (options.unique) {
                chars = unique(chars);
            }

            // 对字符按照编码进行排序
            if (options.sort) {
                chars.sort(sort);
            }

            // 删除无用字符
            chars = chars.join('').replace(/[\n\r\t]/g, '');

            font.chars = chars;

            // 选择器去重
            font.selectors = unique(font.selectors);

            // 转换路径
            font.files = font.files.filter(function(file) {
                var ignore = !options.resourceIgnore(file.source);

                if (!ignore) {
                    file.source = options.resourceMap(file.source);
                }

                return ignore;
            });
        });


        process.nextTick(function() {
            callback(null, list);
        });

        return list;
    }, function(errors) {
        process.nextTick(function() {
            callback(errors);
        });
        return Promise.reject(errors);
    });

}


module.exports = fontSpiderRunner;
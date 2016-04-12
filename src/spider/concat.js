'use strict';

var Adapter = require('../adapter');

/**
 * 合并相同 webFont 的字符、选择器数据
 * @param   {Array<WebFont>}
 * @param   {Adapter}
 * @return  {Array<WebFont>}
 */
function concat(webFonts, adapter) {
    adapter = new Adapter(adapter);
    if (Array.isArray(webFonts[0])) {
        webFonts = reduce(webFonts);
    }

    var newWebFonts = [];
    var indexs = {};


    // 合并相同 font-face
    webFonts.forEach(function(webFont) {
        var id = webFont.id;
        if (typeof indexs[id] === 'number') {
            var item = newWebFonts[indexs[id]];
            item.chars += webFont.chars;
            item.selectors = item.selectors.concat(webFont.selectors);
        } else {
            indexs[id] = newWebFonts.length;
            newWebFonts.push(webFont);
        }
    });


    newWebFonts.forEach(function(font) {

        var chars = font.chars.split('');

        // 对字符进行除重操作
        if (adapter.unique) {
            chars = unique(chars);
        }

        // 对字符按照编码进行排序
        if (adapter.sort) {
            chars.sort(sort);
        }

        // 删除无用字符
        chars = chars.join('').replace(/[\n\r\t]*/g, '');

        font.chars = chars;

        // 选择器去重
        font.selectors = unique(font.selectors);

        // 处理路径
        font.files = font.files.filter(function(file) {
            var ignore = adapter.resourceIgnore(file.source);

            if (!ignore) {
                file.source = adapter.resourceMap(file.source);
            }

            return !ignore;
        });
    });

    indexs = null;

    return newWebFonts;
}



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


module.exports = concat;
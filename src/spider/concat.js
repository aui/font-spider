'use strict';


/**
 * 合并相同 webFont 的字符、选择器数据
 * @param   {Array<Array<WebFont>>}
 * @param   {Adapter}
 * @return  {Array<WebFont>}
 */
function concat(webFonts, adapter) {

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


    newWebFonts.forEach(function(webFont) {

        var chars = webFont.chars.split('');

        // 对字符进行除重操作
        if (adapter.unique) {
            chars = unique(chars);
        }

        // 对字符按照编码进行排序
        if (adapter.sort) {
            chars.sort(sort);
        }

        // 删除无用字符
        chars = chars.join('').replace(/\s*/g, '');

        webFont.chars = chars;

        // 选择器去重
        webFont.selectors = unique(webFont.selectors);

        // 处理路径
        webFont.files = webFont.files.filter(function(file) {
            var ignore = adapter.resourceIgnore(file.url);

            if (!ignore) {
                file.url = adapter.resourceMap(file.url);
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

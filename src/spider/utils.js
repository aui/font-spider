/* global require,module */
'use strict';

var path = require('path');
var url = require('url');
var util = require('util');
var ignore = require('ignore');


// url(../font/font.ttf)
// url("../font/font.ttf")
// url('../font/font.ttf')
var RE_FONT_URL = /url\((.*?)\)/ig;

// "../font/font.ttf"
// '../font/font.ttf'
var RE_QUOTATION = /^['"]|['"]$/g;

// art, lanting, heiti
var RE_SPLIT_COMMA = /\s*,\s*/;

// http://font-spider.org/css/style.css
var RE_SERVER = /^https?\:\/\//i;


// 去除收尾双、单引号
function unquotation (string) {
    return string.replace(RE_QUOTATION, '');
}



/*
 * 浅拷贝（包括原型属性）
 * @param   {Object}    目标对象
 * @param   {Object}    混合进来的对象
 */
function mix (target, object) {
    for (var key in object) {
        target[key] = object[key];
    }
    return target;
}





/*
 * 深度拷贝对象
 * @param   {Object}    目标对象
 * @return  {Object}    复制后的新对象
 */
function copy (data) {
    if (typeof data === 'object' && data !== null) {
        if (Array.isArray(data)) {

            var array = [];
            data.forEach(function (item, index) {
                array[index] = copy(item);
            });

            return array;

        } else {

            var object = Object.create(data); // 保证 instanceof 操作
            Object.keys(data).forEach(function (key) {
                object[key] = data[key];
            });

            return object;
        }
    } else {
        return data;
    }
}




/*
 * 混合配置
 * @param   {Object}    默认配置
 * @param   {Object}    被加入的配置
 */
function options (defaults, config) {
    return mix(Object.create(defaults), config || {});
}




/*
 * 数组除重复
 * @param   {Array}     目标数组
 * @return  {Array}     新数组
 */
function unique (array) {
    var ret = [];

    array.forEach(function (val) {
        if (ret.indexOf(val) === -1) {
            ret.push(val);
        }
    });

    return ret;
}





/*
 * 提取 CSS URL 列表
 * @param   {String}    url("../test.css"), url(file.css)
 * @return  {Array}
 */
function urlToArray (value) {
    var list = [];
    var src;

    RE_FONT_URL.lastIndex = 0;
    while ((src = RE_FONT_URL.exec(value)) !== null) {

        src = src[1];
        src = unquotation(src.trim());
        //src = normalize(src);

        list.push(src);
    }

    return list;
}


// 根据逗号转成数组
function commaToArray (value) {
    return value.trim().split(RE_SPLIT_COMMA);
}


// 扁平化二维数组
function reduce (array) {
    var ret = [];
    array.forEach(function (item) {
        ret.push.apply(ret, item);
    });

    return ret;
}



/*
 * 转换到绝对路径，支持 HTTP 形式
 * @param   {String}    来源目录（请保证是目录，否则远程路径转换可能出错）
 * @param   {String}    子路径
 * @return  {String}    绝对路径
 */
function resolve (from, to) {

    if (isRemote(from)) {

        if (!/\/$/.test(from)) {
            from += '/';
        }

        return url.resolve(from, to);
    } else if (isRemote(to)) {
        return to;
    } else {
        return path.resolve(from, to);
    }
}


/*
 * 标准化路径
 * @param   {String}    路径
 * @return  {String}    标准化路径
 */
function normalize (src) {
    if (isRemote(src)) {
        // http://font/font?name=xxx#x
        // http://font/font?
        return src.replace(/#.*$/, '').replace(/\?$/, '');
    } else {
        // ../font/font.eot?#font-spider
        src = src.replace(/[#?].*$/g, '');
        return path.normalize(src);
    }
}


/*
 * 判断是否为远程 URL
 * @param   {String}     路径
 * @return  {Boolean}
 */
function isRemote (src) {
    return RE_SERVER.test(src);
}



/*
 * 获取目录名
 * @param   {String}    路径
 */
function dirname (src) {
    
    if (isRemote(src)) {

        // http://www.huanleguang.com/////
        src = src.replace(/\/+$/, '');

        // path.dirname('http://www.huanleguang.com') === 'http:/'
        if (url.parse(src).path === '/') {
            return src;
        } else {
            return path.dirname(src);
        }

    } else {
        return path.dirname(src);
    }
}




/*
 * 映射器工厂
 * @param   {Array}     映射规则
 * @return  {Function}
 */
function map (params) {

    var regs = [];
    (params || []).forEach(function (params) {
        if (typeof params[0] === 'string') {
            params[0] = new RegExp(params[0]);
        }
        regs.push(params);
    });

    return function (src) {

        if (!src || !regs || !regs.length) {
            return src;
        }

        if (!Array.isArray(regs[0])) {
            regs = [regs];
        }

        regs.forEach(function (reg) {
            src = src.replace.apply(src, reg);
        });

        return src;
    };
}



/*
 * 筛选器工厂
 * @param   {Array}     规则
 * @return  {Function}
 */
function filter (ignoreList) {
    var fn = ignore({
        ignore: ignoreList || []
    });

    return function (src) {

        if (!src) {
            return;
        }

        if (Array.isArray(src)){
            return fn.filter(src);
        } else {
            return fn.filter([src])[0];
        }
    };
}





module.exports = {
    inherits: util.inherits,
    unquotation: unquotation,
    mix: mix,
    copy: copy,
    options: options,
    unique: unique,
    urlToArray: urlToArray,
    commaToArray: commaToArray,
    reduce: reduce,
    resolve: resolve,
    normalize: normalize,
    dirname: dirname,
    isRemote: isRemote,
    filter: filter,
    map: map
};

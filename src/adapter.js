'use strict';

var path = require('path');
var RE_SEP = new RegExp('\\' + path.sep, 'g');

function Adapter(options) {

    options = options || {};

    if (options instanceof Adapter) {
        return options;
    }

    for (var key in options) {
        this[key] = options[key];
    }
}

Adapter.prototype = {

    constructor: Adapter,

    /**
     * 忽略加载的文件规则（支持正则）- 与 `resourceIgnore` 参数互斥
     * @type    {Array<String>}
     */
    ignore: [],

    /**
     * 映射的文件规则（支持正则）- 与 `resourceMap` 参数互斥 - 可以将远程字体文件映射到本地来
     * @type    {Array<Array<String>>}
     * @example [['http://font-spider.org/font', __diranme + '/font'], ...]
     */
    map: [],

    /**
     * 是否支持备份原字体
     * @type    {Boolean}
     */
    backup: true,

    /**
     * 是否对查询到的文本进行去重处理
     * @type    {Boolean}
     */
    unique: true,

    /**
     * 是否排序查找到的文本
     * @type    {Boolean}
     */
    sort: true,

    /**
     * 是否开启调试模式
     * @type    {Boolean}
     */
    debug: false,

    /*---------- browser-x ----------*/

    /**
     * 文件基础路径 - 仅内部可使用
     * @type    {String}
     */
    url: 'about:blank',

    /*
     * HTML 文本 - 仅内部可使用
     * @type    {String}
     */
    html: null,

    /**
     * 是否支持加载外部 CSS 文件
     * @type    {Boolean}
     */
    loadCssFile: true,

    /**
     * 是否忽略内部解析错误-关闭它有利于开发调试
     * @type    {Boolean}
     */
    silent: true,

    /**
     * 请求超时限制
     * @type    {Number}    毫秒
     */
    resourceTimeout: 8000,

    /**
     * 最大的文件加载数量限制
     * @type    {Number}    数量
     */
    resourceMaxNumber: 64,

    /**
     * 是否缓存请求成功的资源
     * @type    {Boolean}
     */
    resourceCache: true,

    /**
     * 映射资源路径 - 与 `map` 参数互斥
     * @param   {String}    旧文件地址
     * @return  {String}    新文件地址
     */
    resourceMap: function(file) {
        var map = this.map;

        if (!map || map.length === 0) {
            return file;
        }

        this.resourceMap = mapFactory(map);
        return this.resourceMap(file);
    },

    /**
     * 忽略资源 - 与 `ignore` 参数互斥
     * @param   {String}    文件地址
     * @return  {Boolean}   如果返回 `true` 则忽略当当前文件的加载
     */
    resourceIgnore: function(file) { // jshint ignore:line
        var ignore = this.ignore;
        if (!ignore || ignore.length === 0) {
            return false;
        }

        this.resourceIgnore = ignoreFactory(ignore);
        return this.resourceIgnore(file);
    },

    /**
     * 资源加载前的事件
     * @param   {String}    文件地址
     */
    resourceBeforeLoad: function(file) { // jshint ignore:line
    },

    /**
     * 加载远程资源的自定义请求头
     * @param   {String}    文件地址
     * @return  {Object}
     */
    resourceRequestHeaders: function(file) { // jshint ignore:line
        return {
            'accept-encoding': 'gzip,deflate'
        };
    }
};


/**
 * 映射器工厂
 * @param   {Array}     映射规则
 * @return  {Function}
 */
function mapFactory(params) {

    var regs = [];
    (params || []).forEach(function(params) {
        if (typeof params[0] === 'string') {
            params[0] = new RegExp(params[0], 'g');
        }
        regs.push(params);
    });

    // @param   {String}
    // @param   {String}
    return regs.length ? function map(src) {

        if (!src) {
            return src;
        }

        src = src.replace(RE_SEP, '/'); // windows path

        regs.forEach(function(reg) {
            src = src.replace.apply(src, reg);
        });

        return src;

    } : function(src) {
        return src;
    };
}



/**
 * 忽略器工厂
 * @param   {Array}     规则
 * @return  {Function}
 */
function ignoreFactory(ignoreList) {

    ignoreList = ignoreList.map(function(item) {
        if (typeof item === 'string') {
            item = new RegExp(item, 'g');
        }

        return item;
    });

    // @param   {String}
    // @return  {Boolean}
    return ignoreList.length ? function(src) {

        if (!src) {
            return false;
        }

        src = src.replace(RE_SEP, '/'); // windows path

        var index = -1;
        var length = ignoreList.length;
        while (++index < length) {
            if (ignoreList[index].test(src)) {
                return true;
            }
        }

        return false;

    } : function() {
        return false;
    };
}


module.exports = Adapter;
'use strict';

var ignore = require('ignore');

function Adapter(options) {

    options = options || {};

    if (options instanceof Adapter) {
        return options;
    }

    for (var key in options) {
        this[key] = options[key];
    }

    this._resourceCache = {};
}

Adapter.prototype = {

    constructor: Adapter,

    /**
     * 是否对查询到的文本进行去重处理
     */
    unique: true,

    /**
     * 是否排序查找到的文本
     */
    sort: true,

    /**
     * 忽略加载的文件规则
     * @see     https://github.com/kaelzhang/node-ignore
     * @type    {Array<String>}
     */
    ignore: [],

    /**
     * 映射的文件规则-支持正则
     * @type    {Array<Array<String>>}
     */
    map: [],


    /**
     * 是否支持备份原字体
     */
    backup: true,


    /*---------- browser-x ----------*/

    /**
     * 文件基础路径
     */
    baseURI: 'about:blank',

    /*
     * HTML 文本
     */
    html: null,

    /**
     * 是否支持加载外部 CSS 文件
     */
    loadCssFile: true,

    /**
     * 解析时是否静默失败
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
     * @tyoe    {Number}    数量
     */
    resourceMaxNumber: 64,

    /**
     * 获取缓存
     * @return  {Object}
     */
    resourceCache: function() {
        return this._resourceCache;
    },

    /**
     * 映射资源路径
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
     * 忽略资源
     * @param   {String}    文件地址
     * @return  {Boolean}   如果返回`true`则忽略当当前文件的加载
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


/*
 * 映射器工厂
 * @param   {Array}     映射规则
 * @return  {Function}
 */
function mapFactory(params) {

    var regs = [];
    (params || []).forEach(function(params) {
        if (typeof params[0] === 'string') {
            params[0] = new RegExp(params[0]);
        }
        regs.push(params);
    });

    // @param   {String}
    // @param   {String}
    return regs.length ? function map(src) {

        if (!src) {
            return src;
        }

        regs.forEach(function(reg) {
            src = src.replace.apply(src, reg);
        });

        return src;

    } : function(src) {
        return src;
    };
}



/*
 * 忽略器工厂
 * @param   {Array}     规则
 * @return  {Function}
 */
function ignoreFactory(ignoreList) {

    if (typeof ignoreList === 'function') {
        return ignoreList;
    }

    var fn = ignore({
        ignore: ignoreList || []
    });

    // @param   {String}
    // @return  {Boolean}
    return ignoreList.length ? function(src) {

        if (!src) {
            return false;
        }

        return !fn.filter([src])[0];

    } : function() {
        return false;
    };
}


module.exports = Adapter;
/* global require,module,console */

'use strict';

var cheerio = require('cheerio');
var utils = require('./utils');
var Resource = require('./resource');
var Promise = require('./promise');
var VError = require('verror');



function HtmlParser (resource) {


    if (resource instanceof Promise) {
        return resource.then(function (resource) {
            return new HtmlParser(resource);
        });
    }


    if (!(resource instanceof Resource.Model)) {
        throw new Error('require `Resource.Model`');
    }



    var file = resource.file;
    var content = resource.content;
    var options = resource.options;
    var $;


    try {
        $ = cheerio.load(content);
        return new HtmlParser.Parser($, file, options);
    } catch (error) {

        var errors = new VError(error, 'parse "%s" failed', file);

        return Promise.reject(errors);
    }
    
}



/*
 * 默认选项
 */
HtmlParser.defaults = {
    cache: true,        // 缓存开关
    debug: false,       // 调试开关
    ignore: [],         // 忽略的文件配置
    map: []             // 文件映射配置
};



/*
 * @param   {Object}
 * @param   {Object}    Options: ignore | map
 */
HtmlParser.Parser = function Parser ($, file, options) {

    options = utils.options(HtmlParser.defaults, options);

    this.$ = $;

    this.options = options;

    this.file = file;

    // 忽略文件
    this.filter = utils.filter(options.ignore);

    // 对文件地址进行映射
    this.map = utils.map(options.map);

    // TODO <base /> 标签顺序会影响解析
    // /Users/aui/test.html >> /Users/aui
    // http://font-spider.org >>> http://font-spider.org
    // http://font-spider.org/html/test.html >>> http://font-spider.org/html
    this.base = $('base[href]').attr('href') || utils.dirname(file);

    return Promise.resolve(this);
};





HtmlParser.Parser.prototype = {


    constructor: HtmlParser.Parser,


    /*
     * 获取 CSS 文件地址队列
     * @return  {Array} 
     */
    getCssFiles: function () {

        var that = this;
        var base = this.base;
        var $ = this.$;
        var files = [];


        $('link[rel=stylesheet]').each(function () {

            var $this = $(this);
            var cssFile;
            var href = $this.attr('href');

            if (!that.filter([href]).length) {
                return;
            }

            cssFile = utils.resolve(base, href);
            cssFile = that.filter(cssFile);
            cssFile = that.map(cssFile);
            cssFile = utils.normalize(cssFile);

            files.push(cssFile);
        });


        if (this.options.debug) {
            console.log('');
            console.log('[DEBUG]', 'HtmlParser#getCssFiles', this.file);
            console.log(files);
        }


        return files;
    },



    /*
     * 获取 style 标签的内容列表
     * @return  {Array}
     */
    getCssContents: function () {

        var $ = this.$;
        var contents = [];

        $('style').each(function () {
            var $this = $(this);
            var content = $this.text();
            contents.push(content);
        });

        if (this.options.debug) {
            console.log('');
            console.log('[DEBUG]', 'HtmlParser#getCssContents', this.file);
            console.log(contents);
        }

        return contents;
    },


    /*
     * 根据 CSS 选择器规则查找文本节点的文本
     * @param   {String}    CSS 选择器规则
     * @return  {Array}     字符数组
     */
    querySelectorChars: function (selector) {

        var chars = '';
        var that = this;


        // 将多个语句拆开进行查询，避免其中有失败导致所有规则失效
        if (selector.indexOf(',') !== -1) {
            
            selector.split(',').forEach(function (selector) {
                chars += that.querySelectorChars(selector).join('');
            });

            return chars.split('');
        }


        var $elem;
        var $ = this.$;
        var RE_SPURIOUS = /\:(link|visited|hover|active|focus)\b/ig;


        // 剔除状态伪类
        selector = selector.replace(RE_SPURIOUS, '');


        // 使用选择器查找节点
        try {
            $elem = $(selector);
        } catch (e) {
            // 1. 包含 :before \ :after 等不支持的伪类
            // 2. 非法语句
            return [];
        }


        // 查找文本节点
        $elem.each(function () {
            chars += $(this).text();
        });


        chars = chars.split('');


        if (this.options.debug) {
            console.log('');
            console.log('[DEBUG]', 'HtmlParser#querySelectorChars', selector, this.file);
            console.log(chars.join(''));
        }


        return chars;
    }
};




//TODO 支持行内样式

module.exports = HtmlParser;
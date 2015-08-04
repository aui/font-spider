/* global require,module,console */

//TODO 支持行内样式

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


    return new Promise(function (resolve, reject) {
        var file = resource.file;
        var content = resource.content;
        var options = resource.options;
        var $;


        try {
            $ = cheerio.load(content);
        } catch (error) {
            var errors = new VError(error, 'parse "%s" failed', file);
            return reject(errors);
        }


        resolve(new HtmlParser.Parser($, file, options));
    });
    
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



HtmlParser.Parser = function ($, file, options) {

    options = utils.options(HtmlParser.defaults, options);

    this.$ = $;

    this.options = options;

    this.file = file;

    this.ignore = utils.ignore(options.ignore);

    this.map = utils.map(options.map);

    // TODO <base /> 标签顺序会影响解析。
    // 这里只考虑 <base /> 标签在 HTML 顶部的情况
    // /Users/aui/test.html >> /Users/aui
    // http://font-spider.org >>> http://font-spider.org
    // http://font-spider.org/html/test.html >>> http://font-spider.org/html
    this.base = $('base[href]').attr('href') || utils.dirname(file);
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

            cssFile = utils.resolve(base, href);
            cssFile = getUrl(cssFile);

            // 注意：为空也得放进去，保持与 link 标签一一对应
            files.push(cssFile);
        });


        // 转换 file 地址
        // 执行顺序：ignore > map > normalize
        function getUrl (file) {

            if (!that.ignore(file)) {
                file = that.map(file);
                file = utils.normalize(file);
                return file;
            }
        }


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
        var RE_DPSEUDOS = /\:(link|visited|target|active|focus|hover|checked|disabled|enabled|selected|lang\(([-\w]{2,})\)|not\(([^()]*|.*)\))?(.*)/i;


        // 剔除状态伪类
        selector = selector.replace(RE_DPSEUDOS, '');


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



module.exports = HtmlParser;
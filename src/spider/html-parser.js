/* global require,Buffer,module */
'use strict';

var fs = require('fs');
var path = require('path');
var cheerio = require('cheerio');
var utils = require('./utils');
var Resource = require('./resource');
var Promise = typeof Promise === 'function' ? Promise : require('promise');



function HtmlParser (resource) {


    if (resource instanceof Promise) {
        return resource.then(function (resource) {
            return new HtmlParser(resource);
        });
    }


    if (!(resource instanceof Resource.Content)) {
        throw new Error('require `Resource.Content`');
    }


    var file = resource.file;
    var content = resource.content;
    var options = resource.options;
    var $;

    options.base = options.base || path.dirname(file);

    

    try {
        $ = cheerio.load(content);
    } catch (error) {
        utils.warn(error);
        return Promise.reject(error);
    }


    return new HtmlParser.Parser($, options);
}



HtmlParser.Parser = function Parser ($, options) {

    var that = this;

    this.$ = $;

    this.options = options;

    // 忽略文件
    this.filter = utils.filter(options.ignore);

    // 对文件地址进行映射
    this.map = utils.map(options.map);

    // TODO <base /> 标签顺序会影响解析
    this.base = $('base[href]').attr('href') || options.base;

    this.file = options.file;

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
        var htmlFile = this.file;
        var files = [];


        $('link[rel=stylesheet]').each(function () {

            var $this = $(this);
            var cssFile;
            var href = $this.attr('href');


            // 忽略含有有 disabled 属性的
            if (isDisabled($this)) {
                files.push(null); // 确保返回的数组 length 正确
                return;
            }


            if (!that.filter([href]).length) {
                return;
            }

            cssFile = utils.resolve(base, href);
            cssFile = that.filter(cssFile);
            cssFile = that.map(cssFile);
            cssFile = utils.normalize(cssFile);

            files.push(cssFile);
        });


        function isDisabled ($elem) {
            var disabled = $elem.attr('disabled');
            return disabled && disabled !== 'false';
        }


        return files;
    },



    /*
     * 获取 style 标签的内容列表
     * @return  {Array}
     */
    getCssContents: function () {
        var that = this;
        var $ = this.$;
        var htmlFile = this.file;
        var contents = [];

        $('style').each(function () {
            var $this = $(this);
            var content = $this.text();
            contents.push(content);
        });

        return contents;
    },


    /*
     * 根据 CSS 选择器规则查找文本节点的文本
     * @param   {String}    CSS 选择器规则
     * @return  {Array}     字符数组
     */
    querySelectorChars: function (selector) {
        var $elem;
        var $ = this.$;
        var chars = [];
        var RE_SPURIOUS = /\:(link|visited|hover|active|focus)\b/ig;

        // 剔除状态伪类
        selector = selector.replace(RE_SPURIOUS, '');

        // 使用选择器查找节点
        try {
            $elem = $(selector);
        } catch (e) {
            // 1. 包含 :before 等不支持的伪类
            // 2. 其他非法语句
            return chars;
        }

        // 查找文本节点
        $elem.each(function () {
            chars.push($(this).text());
        });

        return chars;
    }
};




//TODO 支持行内样式

module.exports = HtmlParser;
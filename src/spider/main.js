/* global require,module */

'use strict';

var fs = require('fs');
var path = require('path');
var cheerio = require('cheerio');
var utils = require('./utils');
var logUtil = require('./log-util');
var Resource = require('./resource');
var CssParser = require('./css-parser');
var HtmlParser = require('./html-parser');
var Promise = require('./promise');


function Spider (htmlFiles, options) {

    options = options || {};


    // 支持单个 HTML 地址传入
    if (typeof htmlFiles === 'string') {
        htmlFiles = [htmlFiles];
    }


    // 处理多个 HTML，这些 HTML 文件可能会引用相同的 CSS
    return Promise.all(htmlFiles.map(function (htmlFile) {
        return new Spider.Parser(htmlFile, options);
    })).then(function (list) {

        function sort (a, b) {
            return a.charCodeAt() - b.charCodeAt();
        }

        return utils.reduce(list).map(function (font) {

            // 对字符进行除重操作
            font.chars = utils.unique(font.chars);

            // 对字符按照编码进行排序
            if (options.sort) {
                font.chars.sort(sort);
            }

            return new Spider.Model(
                font.family,
                font.files,
                font.chars.join('').replace(/[\n\r\t]/g, ''),
                font.selectors
            );
        });

    });


}


Spider.Model = function (name, files, chars, selectors) {
    this.name = name;
    this.files = files;
    this.chars = chars;
    this.selectors = selectors;
};


/*
 * 解析 HTML
 * @param   {String}            文件绝对路径
 * @return  {Promise}
 */
Spider.Parser = function Parser (htmlFile, options) {

    options = utils.mix({
        from: 'Node',
        cache: false
    }, (options || {}));

    var $;
    var resource;
    var that = this;
    var isBuffer = typeof htmlFile === 'object' && htmlFile.isBuffer();


    if (isBuffer) {

        resource = Promise.resolve(new Resource.Content(
            htmlFile.path,
            htmlFile.contents.toString(),
            utils.mix(options, {
                base: path.dirname(htmlFile.path)
            })
        ));

    } else {

        utils.mix(options, {
            base: path.dirname(htmlFile)
        });

        resource = new Resource(htmlFile, null, options);
    }


    return new HtmlParser(resource)
    .then(function (htmlParser) {
        this.htmlParser = htmlParser;
        this.htmlFile = htmlFile;
        return htmlParser;
    }.bind(this))
    .then(that.getCssInfo.bind(this))
    .then(this.getFontInfo.bind(this))
    .then(this.getCharsInfo.bind(this));
};


Spider.Parser.prototype = {


    constructor: Spider.Parser,


    /*
     * 获取当前页面 link 标签与 style 标签的 CSS 解析结果
     * @return      {Promise}   Array<CssParser.Model>
     */
    getCssInfo: function () {

        var htmlFile = this.htmlFile;
        var htmlParser = this.htmlParser;
        var resources = [];

        // 获取外链样式资源
        var cssFiles =  htmlParser.getCssFiles();

        // 获取 style 标签内容资源
        var cssContents =  htmlParser.getCssContents();


        cssFiles.forEach(function (cssFile, index) {

            if (!cssFile) {
                return;
            }

            var line = index + 1;
            var form = htmlFile + '#<link:nth-of-type(' + line + ')>';
            resources.push(new Resource(cssFile, null, {
                cache: true,
                form: form
            }));
        });


        cssContents.forEach(function (content, index) {

            if (!content) {
                return;
            }

            var line = index + 1;
            var form = htmlFile + '#<style:nth-of-type(' + line + ')>';
            resources.push(new Resource(form, content, {
                cache: true,
                form: form
            }));
        });


        return Promise.all(resources.map(CssParser))

        // 对二维数组扁平化处理
        .then(utils.reduce);
    },


    /*
     * 分析 CSS 中的字体相关信息
     */
    getFontInfo: function (cssInfo) {

        var fontFaces = [];
        var styleRules = [];

        // 分离 @font-face 数据与选择器数据
        cssInfo.forEach(function (item) {
            if (item.type === 'CSSFontFaceRule') {
                fontFaces.push(item);
            } else if (item.type === 'CSSStyleRule') {
                styleRules.push(item);
            }

        });


        // 匹配选择器与 @font-face 定义的字体
        fontFaces.forEach(function (fontFace) {
            styleRules.forEach(function (styleRule) {

                if (styleRule.ids.indexOf(fontFace.id) !== -1) {
    
                    fontFace.selectors = fontFace.selectors.concat(styleRule.selectors);
                    fontFace.chars = fontFace.chars.concat(styleRule.chars);

                }

            });
        });


        return fontFaces;
    },


    getCharsInfo: function (fontFaces) {
        var that = this;
        fontFaces.forEach(function (fontFace) {
            var $elem;
            var selector = fontFace.selectors.join(', ');
            var chars = that.htmlParser.querySelectorChars(selector);
            fontFace.chars = fontFace.chars.concat(chars);
        });

        return fontFaces;
    }
};

// TODO
Spider.defaults = {
    sort: true,         // 是否将查询到的文本按字体中字符的顺序排列
    unique: true,       // 是否去除重复字符
    ignore: [],         // 忽略的文件配置
    map: []             // 文件映射配置
};


Spider.on = logUtil.on;



module.exports = Spider;
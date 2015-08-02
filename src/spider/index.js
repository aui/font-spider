/* global require,module */

'use strict';


var utils = require('./utils');
var Resource = require('./resource');
var CssParser = require('./css-parser');
var HtmlParser = require('./html-parser');
var Promise = require('./promise');
var push = Array.prototype.push;





function Spider (htmlFiles, options) {

    options = utils.options(Spider.defaults, options);


    // 支持单个 HTML 地址传入
    if (typeof htmlFiles === 'string') {
        htmlFiles = [htmlFiles];
    }


    // 处理多个 HTML，这些 HTML 文件可能会引用相同的 CSS
    return Promise.all(htmlFiles.map(function (htmlFile) {
        return new Spider.Parser(htmlFile, options);
    })).then(function (list) {


        var webFonts = [];
        var chars = {};
        var unique = {};


        utils.reduce(list).forEach(function (font) {
            var charsCache = chars[font.id];

            if (charsCache) {

                // 合并多个页面查询到的字符
                push.apply(charsCache, font.chars);

            } else if (!unique[font.id]) {

                unique[font.id] = true;
                chars[font.id] = font.chars;

                webFonts.push(new Spider.Model(
                    font.id,
                    font.family,
                    font.files,
                    font.chars,
                    font.selectors
                ));
            }

        });

        webFonts.forEach(function (font) {

            font.chars = chars[font.id];

            // 对字符进行除重操作
            if (options.unique) {
                font.chars = utils.unique(font.chars);
            }
            

            // 对字符按照编码进行排序
            if (options.sort) {
                font.chars.sort(sort);
            }

            // 将数组转成字符串并删除无用字符
            font.chars = font.chars.join('').replace(/[\n\r\t]/g, '');
        });


        return webFonts;

        function sort (a, b) {
            return a.charCodeAt() - b.charCodeAt();
        }

    });


}



Spider.Model = function WebFont (id, name, files, chars, selectors) {
    this.id = id;
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
Spider.Parser = function (htmlFile, options) {
    return new Promise(function (resolve, reject) {
        var resource;
        var isBuffer = typeof htmlFile === 'object' && htmlFile.isBuffer();

        if (isBuffer) {

            resource = resolve(new Resource.Model(
                htmlFile.path,
                htmlFile.contents.toString(),
                utils.options(options, {
                    from: 'Node',
                    cache: false
                })
            ));

            htmlFile = htmlFile.path;

        } else {

            resource = new Resource(
                htmlFile,
                null,
                utils.options(options, {
                    from: 'Node',
                    cache: false
                }
            ));
        }


        this.options = options;
        var spiderBeforeLoad = options.spiderBeforeLoad;
        var spiderLoad = options.spiderLoad;
        var spiderError = options.spiderError;

        spiderBeforeLoad(htmlFile);

        new HtmlParser(resource)
        .then(function (htmlParser) {
            this.htmlParser = htmlParser;
            this.htmlFile = htmlFile;
            return htmlParser;
        }.bind(this))
        .then(this.getCssInfo.bind(this))
        .then(this.getFontInfo.bind(this))
        .then(this.getCharsInfo.bind(this))
        .then(function (webFonts) {
            spiderLoad(htmlFile);
            resolve(webFonts);
        })
        .catch(function (errors) {
            spiderError(htmlFile, errors);
            reject(errors);
        });
    }.bind(this));
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
        var options = this.options;
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
            var from = 'link:nth-of-type(' + line + ')';

            resources.push(
                new Resource(
                    cssFile,
                    null,
                    utils.options(options, {
                        cache: true,
                        from: from
                    })
                )
            );

        });


        cssContents.forEach(function (content, index) {

            if (!content) {
                return;
            }

            var line = index + 1;
            var from = 'style:nth-of-type(' + line + ')';
            var cssFile = htmlFile + '#' + from;
            resources.push(
                new Resource(
                    cssFile,
                    content,
                    utils.options(options, {
                        cache: false,
                        from: from
                    })
                )
            );
        });



        return Promise.all(resources.map(function (resource) {
            return new CssParser(resource);
        }))

        // 对二维数组扁平化处理
        .then(utils.reduce);
    },


    /*
     * 分析 CSS 中的字体相关信息
     */
    getFontInfo: function (cssInfo) {

        var webFonts = [];
        var styleRules = [];

        // 分离 @font-face 数据与选择器数据
        cssInfo.forEach(function (item) {
            if (item.type === 'CSSFontFaceRule') {
                webFonts.push(item);
            } else if (item.type === 'CSSStyleRule') {
                styleRules.push(item);
            }
        });


        // 匹配选择器与 @font-face 定义的字体
        webFonts.forEach(function (fontFace) {
            styleRules.forEach(function (styleRule) {

                if (styleRule.id.indexOf(fontFace.id) !== -1) {
    
                    push.apply(fontFace.selectors, styleRule.selectors);
                    fontFace.selectors = utils.unique(fontFace.selectors);

                    // css content 属性收集的字符
                    push.apply(fontFace.chars, styleRule.chars);

                }

            });
        });


        return webFonts;
    },


    getCharsInfo: function (webFonts) {
        var that = this;
        webFonts.forEach(function (fontFace) {
            var selector = fontFace.selectors.join(', ');
            var chars = that.htmlParser.querySelectorChars(selector);
            push.apply(fontFace.chars, chars);

        });

        return webFonts;
    }
};



/*
 * 默认选项
 */
Spider.defaults = {
    spiderBeforeLoad: function () {},
    spiderLoad: function () {},
    spiderError: function () {},
    debug: false,
    sort: true,        // 是否将查询到的文本按字体中字符的顺序排列
    unique: true       // 是否去除重复字符
};

utils.mix(Spider.defaults, CssParser.defaults);
utils.mix(Spider.defaults, HtmlParser.defaults);
utils.mix(Spider.defaults, Resource.defaults);



module.exports = Spider;
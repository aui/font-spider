'use strict';

var browser = require('browser-x');
var utils = require('./utils');
var Adapter = require('../adapter');
var WebFont = require('./web-font');
var concat = require('./concat');


/**
 * 蜘蛛类
 * @param   {Window}            浏览器全局对象 @see browser-x
 * @return  {Array<WebFont>}    WebFont 描述信息 @see ./web-font.js
 */
function FontSpider(window) {
    return this.parse(window);
}

FontSpider.prototype = {

    constructor: FontSpider,
    window: null,
    document: null,



    /**
     * parser
     * @param   {Window}
     * @return  {Array<WebFont>}
     */
    parse: function(window) {
        var that = this;
        var document = window.document;

        this.window = window;
        this.document = document;

        var webFonts = [];

        // 这是一个索引值与 webFonts 对应的二维数组，
        // 用来记录 webFonts 所对应的元素列表
        var elements = [];

        var pseudoCssStyleRules = [];
        var inlineStyleSelectors = 'body[style*="font"], body [style*="font"]';
        var inlineStyleElements = document.querySelectorAll(inlineStyleSelectors);



        // 找到 fontFace
        this.eachCssFontFaceRule(function(cssRule) {
            var webFont = WebFont.parse(cssRule);
            if (webFont) {
                webFonts.push(webFont);
            }
        });



        webFonts.forEach(function(webFont, index) {
            elements[index] = [];

            that.eachCssStyleRule(function(cssStyleRule) {

                // 如果当前规则包含已知的 webFont
                if (webFont.match(cssStyleRule.style)) {

                    webFont.selectors.push(cssStyleRule.selectorText);

                    if (that.hasContent(cssStyleRule)) {
                        // 伪元素直接拿 content 字段
                        webFont.chars += that.parseContent(cssStyleRule);
                    } else {

                        // 通过选择器查找元素拥有的文本节点
                        that.getElements(cssStyleRule.selectorText).forEach(function(element) {
                            webFont.chars += element.textContent;
                            if (elements[index].indexOf(element) === -1) {
                                elements[index].push(element);
                            }
                        });
                    }

                } else if (that.hasContent(cssStyleRule)) {
                    // 暂存伪元素，以便进一步分析
                    pseudoCssStyleRules.push(cssStyleRule);
                }

            });
        });



        // 行内样式
        Array.prototype.forEach.call(inlineStyleElements, function(element) {
            var style = element.style;
            webFonts.forEach(function(webFont, index) {
                if (webFont.match(style)) {
                    webFont.chars += element.textContent;
                    if (elements[index].indexOf(element) === -1) {
                        elements[index].push(element);
                    }
                }
            });
        });



        // 分析伪元素所继承的字体
        pseudoCssStyleRules.forEach(function(cssStyleRule) {
            var pseudoElements = that.getElements(cssStyleRule.selectorText, true);
            pseudoElements.forEach(function(pseudoElement) {
                webFonts.forEach(function(webFont, index) {
                    if (containsPseudo(elements[index], pseudoElement)) {
                        var selector = cssStyleRule.selectorText;
                        var char = that.parseContent(cssStyleRule);
                        webFont.selectors.push(selector);
                        webFont.chars += char;
                    }
                });
            });

        });



        function containsPseudo(elements, element) {
            if (!elements.length) {
                return false;
            }

            // 向上查找效率比较高
            while (element) {
                if (elements.indexOf(element) !== -1) {
                    return true;
                }
                element = element.parentNode;
            }

            return false;
        }



        elements = null;
        pseudoCssStyleRules = null;
        inlineStyleElements = null;

        return webFonts;
    },



    /**
     * 解析伪元素 content 属性值。
     * 仅支持 `content: 'prefix'` 和 `content: attr(value)` 这两种形式
     * @see https://developer.mozilla.org/zh-CN/docs/Web/CSS/content
     * @param   {CSSStyleRule}
     * @return  {String}
     */
    parseContent: function(cssStyleRule) {

        var content = cssStyleRule.style.content;
        var string = '';
        var exec, value, index, elements, length;

        var RE_CONTENT = /("(?:\\"|[^"])*"|'(?:\\'|[^']*)'|\battr\([^\)]*\))/ig;
        var RE_STRING = /^["'](.*)["']$/;
        var RE_ATTR = /^attr\(([^\)]*)\)$/i;

        RE_CONTENT.lastIndex = 0;

        while ((exec = RE_CONTENT.exec(content)) !== null) {
            if (value = exec[0].match(RE_STRING)) {
                string += value[1];
            } else if (value = exec[0].match(RE_ATTR)) {
                elements = this.getElements(cssStyleRule.selectorText, true);
                index = -1;
                length = elements.length;
                while (++ index < length) {
                    string += elements[index].getAttribute(value[1]) || '';
                }
            }
        }

        return string;
    },



    /**
     * 根据选择器查找元素，支持伪类和伪元素
     * @param   {String}
     * @param   {Boolean}        是否支持伪元素
     * @return  {Array<Element>} 元素列表
     */
    getElements: function(selector, matchPseudoParent) {
        var that = this;
        var document = this.document;
        var RE_DPSEUDOS = /\:(link|visited|target|active|focus|hover|checked|disabled|enabled|selected|lang\(([-\w]{2,})\)|not\(([^()]*|.*)\))?(.*)/i;


        // 将多个语句拆开进行查询，避免其中有失败导致所有规则失效
        if (selector.indexOf(',') !== -1) {

            var elements = [];
            var selectors = utils.split(selector, ',');

            selectors.forEach(function(selector) {
                elements = elements.concat(that.getElements(selector, matchPseudoParent));
            });

            return elements;
        }

        // 伪类
        selector = selector.replace(RE_DPSEUDOS, '');

        // 伪元素
        if (matchPseudoParent) {
            // .selector ::after
            // ::after
            selector = selector.replace(/\:\:?(?:before|after)$/i, '') || '*';
        }


        try {
            return Array.prototype.slice.call(document.querySelectorAll(selector));
        } catch (e) {
            return [];
        }
    },



    /**
     * 判断是否有 content 属性，且有效
     * @param   {CSSStyleRule}
     * @return  {Boolean}
     */
    hasContent: function(cssStyleRule) {
        var selectorText = cssStyleRule.selectorText;
        var style = cssStyleRule.style;
        var content = style.content;

        if (content && /\:\:?(?:before|after)$/i.test(selectorText)) {
            return true;
        } else {
            return false;
        }
    },



    /**
     * 遍历每一条字体声明规则
     * @param   {Function}
     */
    eachCssFontFaceRule: function(callback) {
        var window = this.window;
        var CSSFontFaceRule = window.CSSFontFaceRule;
        this.eachCssRuleList(function(cssRule) {
            if (cssRule instanceof CSSFontFaceRule) {
                callback(cssRule);
            }
        });
    },



    /**
     * 遍历每一条选择器的规则
     * @param   {Function}
     */
    eachCssStyleRule: function(callback) {

        var window = this.window;
        var CSSStyleRule = window.CSSStyleRule;

        this.eachCssRuleList(function(cssRule) {
            if (cssRule instanceof CSSStyleRule) {
                callback(cssRule);
            }
        });
    },



    /**
     * 遍历每一条规则
     * @param   {Function}
     */
    eachCssRuleList: function(callback) {

        var window = this.window;
        var document = window.document;
        var CSSImportRule = window.CSSImportRule;
        var CSSMediaRule = window.CSSMediaRule;

        function styleSheetListFor(styleSheetList, callback) {
            var index = -1;
            var length = styleSheetList.length;
            var cssStyleSheet, cssRuleList;

            while (++index < length) {
                cssStyleSheet = styleSheetList[index];
                cssRuleList = cssStyleSheet.cssRules || [];
                cssRuleListFor(cssRuleList, callback);
            }
        }

        function cssRuleListFor(cssRuleList, callback) {
            var index = -1;
            var length = cssRuleList.length;
            var cssRule, cssStyleSheet;

            while (++index < length) {
                cssRule = cssRuleList[index];

                if (cssRule instanceof CSSImportRule) {
                    cssStyleSheet = cssRule.styleSheet;
                    cssRuleListFor(cssStyleSheet.cssRules || [], callback);
                } else if (cssRule instanceof CSSMediaRule) {
                    cssRuleListFor(cssRule.cssRules || [], callback);
                } else {
                    callback(cssRule);
                }
            }
        }


        styleSheetListFor(document.styleSheets, callback);
    }

};



/**
 * 查找页面所使用的字体，得到 WebFonts 描述信息 @see ./web-font.js
 * @param   {Array<String>}     网页路径列表
 * @param   {Adapter}           选项
 * @param   {Function}          回调函数
 * @return  {Promise}           如果没有 `callback` 参数则返回 `Promise` 对象
 */
module.exports = function(htmlFiles, adapter, callback) {
    adapter = new Adapter(adapter);

    if (!Array.isArray(htmlFiles)) {
        htmlFiles = [htmlFiles];
    }

    var webFonts = Promise.all(htmlFiles.map(function(htmlFile) {
        var options = Object.create(adapter);

        if (typeof htmlFile === 'string') {
            options.url = htmlFile;

        } else if (htmlFile.path && htmlFile.contents) {
            // 支持 gulp
            options.url = htmlFile.path;
            options.html = htmlFile.contents.toString();
        }

        return browser(options).then(function(window) {
            return new FontSpider(window);
        });
    })).then(function(list) {

        // 合并字体、字符除重、字符排序、路径忽略、路径映射
        return concat(list, adapter);
    });



    if (typeof callback === 'function') {
        webFonts.then(function(webFonts) {
            process.nextTick(function() {
                callback(null, webFonts);
            });
            return webFonts;
        }).catch(function(errors) {
            process.nextTick(function() {
                callback(errors);
            });
            return Promise.reject(errors);
        });
    } else {
        return webFonts;
    }

};
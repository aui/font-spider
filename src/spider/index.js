'use strict';

var WebFont = require('./web-font');
var utils = require('./utils');
var browser = require('browser-x');
var Adapter = require('../adapter');

/**
 * @param   {Window}
 * @return  {Array<WebFont>}
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
        var elements = []; //Array<Array>
        var pseudoCssStyleRules = [];
        var inlineStyleElements = document.querySelectorAll('[style*="font"]');

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
                        webFont.chars += that.parsePseudoContent(cssStyleRule);
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
                        var char = that.parsePseudoContent(cssStyleRule);
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
     * 解析伪元素 content 属性值
     * @param   {CSSStyleRule}
     * @return  {String}
     */
    parsePseudoContent: function(cssStyleRule) {
        var content = cssStyleRule.style.content;

        // TODO 支持 content 所有规则，如属性描述符
        if (/^("[^"]*?"|'[^']*?')$/.test(content)) {

            content = content.replace(/^["']|["']$/g, '');

            return content;
        } else {
            return '';
        }
    },


    /**
     * 根据选择器查找元素，支持伪类和伪元素
     * @param   {String}
     * @param   {Boolean}       是否支持伪元素
     * @return  {Array}         元素列表
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
            for (var i = 0; i < styleSheetList.length; i++) {
                var cssStyleSheet = styleSheetList[i];
                var cssRuleList = cssStyleSheet.cssRules || [];
                cssRuleListFor(cssRuleList, callback);
            }
        }

        function cssRuleListFor(cssRuleList, callback) {
            for (var n = 0; n < cssRuleList.length; n++) {
                var cssRule = cssRuleList[n];

                if (cssRule instanceof CSSImportRule) {
                    var cssStyleSheet = cssRule.styleSheet;
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
 * 启动爬虫
 * @param   {String}
 * @param   {Adapter}
 * @param   {Promise}
 */
module.exports = function(htmlFile, adapter) {
    adapter = new Adapter(adapter);
    return browser.open(htmlFile, adapter).then(function(window) {
        return new FontSpider(window);
    });
};
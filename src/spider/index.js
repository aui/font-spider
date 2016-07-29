'use strict';

var browser = require('browser-x');
var utils = require('./utils');
var Adapter = require('../adapter');
var WebFont = require('./web-font');
var concat = require('./concat');
var colors = require('colors/safe');

/**
 * 蜘蛛类
 * @param   {Window}            浏览器全局对象 @see browser-x
 * @param   {Boolean}           是否开启 debug 模式
 * @return  {Array<WebFont>}    WebFont 描述信息 @see ./web-font.js
 */
function FontSpider(window, debug) {
    this.window = window;
    this.document = window.document;
    this.debug = debug;

    if (debug) {
        this.debugInfo({
            url: window.document.URL
        });
    }

    return this.parse();
}

FontSpider.prototype = {

    constructor: FontSpider,
    window: null,
    document: null,



    /**
     * parser
     * @return  {Array<WebFont>}
     */
    parse: function() {
        var that = this;
        var webFonts = this.getWebFonts();


        if (!webFonts.length) {
            return webFonts;
        }


        var cssStyleRules = this.getCssStyleRules();
        var pseudoCssStyleRules = [];
        var pseudoSelector = /\:\:?(?:before|after)$/i;
        var inlineStyleSelectors = 'body[style*="font"], body [style*="font"]';


        cssStyleRules.forEach(function(cssStyleRule) {
            var style = cssStyleRule.style;
            var selectors = cssStyleRule.selectorText;
            webFonts.forEach(function(webFont) {

                // 如果当前规则包含已知的 webFont
                if (webFont.matchStyle(style)) {

                    that.getSelectors(selectors).forEach(function(selector) {
                        var chars = '';

                        if (pseudoSelector.test(selector)) {

                            // 伪元素直接拿 content 字段
                            chars = that.getContent(selector, style.content);

                        } else {

                            // 通过选择器查找元素拥有的文本节点
                            that.getElements(selector).forEach(function(element) {
                                var content = element.textContent;

                                // @see https://github.com/aui/font-spider/issues/99
                                if (!content && (element.nodeName === 'INPUT' || element.nodeName === 'TEXTAREA')) {
                                    // TODO element.getAttribute('value')
                                    content = element.getAttribute('placeholder');
                                }

                                chars += content || '';
                                webFont.addElement(element);
                            });
                        }


                        webFont.addChar(chars);
                        webFont.addSelector(selector);

                        if (that.debug) {
                            that.debugInfo({
                                family: webFont.family,
                                selector: selector,
                                chars: chars,
                                type: 1
                            });
                        }
                    });

                    // 没有显式声明字体的伪元素需要进一步计算获取继承字体
                } else if (style.content && !WebFont.getComputedFontFamilys(style).length) {

                    pseudoCssStyleRules.push(cssStyleRule);
                }

            });
        });


        // 行内样式
        this.getSelectors(inlineStyleSelectors).forEach(function(selector) {
            that.getElements(selector).forEach(function(element) {
                var style = element.style;
                webFonts.forEach(function(webFont) {
                    if (webFont.matchStyle(style)) {
                        var chars = element.textContent;

                        webFont.addChar(chars);
                        webFont.addElement(element);

                        if (that.debug) {
                            that.debugInfo({
                                family: webFont.family,
                                selector: selector,
                                chars: chars,
                                type: 2
                            });
                        }
                    }
                });
            });
        });



        // 分析伪元素所继承的字体
        pseudoCssStyleRules.forEach(function(cssStyleRule) {
            var content = cssStyleRule.style.content;
            var selectors = cssStyleRule.selectorText;
            that.getSelectors(selectors).filter(function(selector) {
                return pseudoSelector.test(selector);
            }).forEach(function(selector) {

                that.getElements(selector, true).forEach(function(element) {
                    webFonts.forEach(function(webFont) {

                        if (!webFont.matchElement(element)) {
                            return;
                        }

                        var chars = that.getContent(selector, content);
                        webFont.addChar(chars);
                        webFont.addSelector(selector);

                        if (that.debug) {
                            that.debugInfo({
                                family: webFont.family,
                                selector: selector,
                                chars: chars,
                                type: 3
                            });
                        }

                    });
                });

            });
        });


        pseudoCssStyleRules = null;

        webFonts = webFonts.map(function(webFont) {
            return webFont.toData();
        });


        return webFonts;
    },



    /**
     * 解析伪元素 content 属性值
     * 仅支持 `content: 'prefix'` 和 `content: attr(value)` 这两种或组合的形式
     * @see https://developer.mozilla.org/zh-CN/docs/Web/CSS/content
     * @param   {String}
     * @param   {String}
     * @return  {String}
     */
    getContent: function(selector, content) {

        var string = '';
        var tokens = [];

        try {
            tokens = utils.cssContentParser(content);
        } catch (e) {}

        tokens.map(function(token) {
            if (token.type === 'string') {
                string += token.value;
            } else if (token.type === 'attr') {
                var elements = this.getElements(selector, true);
                var index = -1;
                var length = elements.length;
                while (++index < length) {
                    string += elements[index].getAttribute(token.value) || '';
                }
            }
        }, this);

        return string;
    },



    /**
     * 根据选择器查找元素，支持伪类和伪元素
     * @param   {String}            选择器
     * @param   {Boolean}           是否支持伪元素
     * @return  {Array<Element>}    元素列表
     */
    getElements: function(selector, matchPseudoParent) {
        var document = this.document;
        var RE_DPSEUDOS = /\:(link|visited|target|active|focus|hover|checked|disabled|enabled|selected|lang\(([-\w]{2,})\)|not\(([^()]*|.*)\))?(.*)/i;
        var elements = [];

        // 伪类
        selector = selector.replace(RE_DPSEUDOS, '');

        // 伪元素
        if (matchPseudoParent) {
            // .selector ::after
            // ::after
            selector = selector.replace(/\:\:?(?:before|after)$/i, '') || '*';
        }


        try {
            elements = document.querySelectorAll(selector);
            elements = Array.prototype.slice.call(elements);
        } catch (e) {}

        return elements;
    },



    /**
     * 获取选择器列表
     * @param   {String}
     * @return  {Array<String>}
     */
    getSelectors: function(selector) {
        return utils.split(selector).map(function(selector) {
            return selector.trim();
        });
    },



    /**
     * 获取 WebFonts
     * @param   {Array<WebFont>}
     */
    getWebFonts: function() {
        var window = this.window;
        var CSSFontFaceRule = window.CSSFontFaceRule;
        var webFonts = [];
        this.eachCssRuleList(function(cssRule) {
            if (cssRule instanceof CSSFontFaceRule) {
                var webFont = WebFont.parse(cssRule);
                if (webFont) {
                    webFonts.push(webFont);
                }
            }
        });

        return webFonts;
    },



    /**
     * @return {Array<CSSStyleRule>}
     */
    getCssStyleRules: function() {

        var window = this.window;
        var CSSStyleRule = window.CSSStyleRule;
        var cssStyleRules = [];

        this.eachCssRuleList(function(cssRule) {
            if (cssRule instanceof CSSStyleRule) {
                cssStyleRules.push(cssRule);
            }
        });

        return cssStyleRules;
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


        var index = -1;
        var styleSheetList = document.styleSheets;
        var length = styleSheetList.length;
        var cssStyleSheet, cssRuleList;

        while (++index < length) {
            cssStyleSheet = styleSheetList[index];
            cssRuleList = cssStyleSheet.cssRules || [];
            cssRuleListFor(cssRuleList, callback);
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
    },



    /**
     * 显示调试信息
     * @param   {Object}
     */
    debugInfo: function(message) {
        console.log(
            colors.bgYellow('DEBUG'),
            '{',
            Object.keys(message).map(function(key) {
                var value = message[key];
                return JSON.stringify(key) + ': ' + colors.green(JSON.stringify(value));
            }).join(', '),
            '}'
        );
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
            return new FontSpider(window, adapter.debug);
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
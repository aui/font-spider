'use strict';

var browser = require('browser-x');
var parsers = require('./parsers');
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
        console.log(colors.yellow('DEBUG'), [
            'document.URL: ' + colors.green(window.document.URL)
        ].join('; '));
    }

    return this.parse(window);
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
        var document = this.document;
        var webFonts = this.getWebFonts();

        var pseudoCssStyleRules = [];
        var inlineStyleSelectors = 'body[style*="font"], body [style*="font"]';
        var inlineStyleElements = document.querySelectorAll(inlineStyleSelectors);

        // 存储使用对应字体的元素
        var webFontCache = {
            cache: {},
            push: function(id, element) {

                if (!this.cache[id]) {
                    this.cache[id] = [];
                }

                if (this.cache[id].indexOf(element) === -1) {
                    this.cache[id].push(element);
                }
            },
            get: function(id) {
                return this.cache[id];
            }
        };


        webFonts.forEach(function(webFont) {

            that.eachCssStyleRule(function(cssStyleRule) {

                // 如果当前规则包含已知的 webFont
                if (webFont.match(cssStyleRule.style)) {

                    parsers.split(cssStyleRule.selectorText).forEach(function(selector) {
                        var chars = '';

                        if (/\:\:?(?:before|after)$/i.test(selector)) {

                            // 伪元素直接拿 content 字段
                            chars = that.getContent(selector, cssStyleRule.style.content);

                        } else {

                            // 通过选择器查找元素拥有的文本节点
                            that.getElements(selector).forEach(function(element) {
                                chars += element.textContent;
                                webFontCache.push(webFont.id, element);
                            });
                        }

                        webFont.selectors.push(selector);
                        webFont.chars += chars;

                        if (that.debug) {
                            console.log(colors.yellow('DEBUG'), [
                                'family: ' + colors.green(webFont.family),
                                'selectors: ' + colors.green(selector),
                                'chars: ' + colors.green(chars)
                            ].join('; '));
                        }
                    });


                } else if (cssStyleRule.style.content) {
                    // 暂存伪元素，以便进一步分析
                    pseudoCssStyleRules.push(cssStyleRule);
                }

            });
        });



        // 行内样式
        Array.prototype.forEach.call(inlineStyleElements, function(element) {
            var style = element.style;
            webFonts.forEach(function(webFont) {
                if (webFont.match(style)) {
                    webFont.chars += element.textContent;

                    if (that.debug) {
                        console.log(colors.yellow('DEBUG'), [
                            'family: ' + colors.green(webFont.family),
                            'selectors: ' + colors.green('FONTSPIDER, ' + inlineStyleSelectors),
                            'chars: ' + colors.green(element.textContent)
                        ].join('; '));
                    }

                    webFontCache.push(webFont.id, element);
                }
            });
        });


        // 分析伪元素所继承的字体
        pseudoCssStyleRules.forEach(function(cssStyleRule) {

            parsers.split(cssStyleRule.selectorText).forEach(function(selector) {

                that.getElements(selector, true).forEach(function(pseudoElement) {
                    webFonts.forEach(function(webFont) {
                        if (containsPseudo(webFontCache.get(webFont.id), pseudoElement)) {

                            var char = that.getContent(selector, cssStyleRule.style.content);
                            webFont.selectors.push(selector);
                            webFont.chars += char;

                            if (that.debug) {
                                console.log(colors.yellow('DEBUG'), [
                                    'family: ' + colors.green(webFont.family),
                                    'selectors: ' + colors.green(selector),
                                    'chars: ' + colors.green(char)
                                ].join('; '));
                            }

                        }
                    });
                });

            });

        });



        function containsPseudo(elements, element) {
            if (!elements || !elements.length) {
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



        webFontCache = null;
        pseudoCssStyleRules = null;
        inlineStyleElements = null;

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
            tokens = parsers.cssContentParser(content);
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
     * @param   {String}
     * @param   {Boolean}        是否支持伪元素
     * @return  {Array<Element>} 元素列表
     */
    getElements: function(selector, matchPseudoParent) {
        var document = this.document;
        var RE_DPSEUDOS = /\:(link|visited|target|active|focus|hover|checked|disabled|enabled|selected|lang\(([-\w]{2,})\)|not\(([^()]*|.*)\))?(.*)/i;

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
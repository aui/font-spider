'use strict';

var crypto = require('crypto');
var nodeUrl = require('url');
var nodePath = require('path');
var utils = require('./utils');
var cssFontParser = require('css-font-parser');

var KEYWORDS = ['serif', 'sans-serif', 'monospace', 'cursive', 'fantasy', 'initial', 'inherit'];
var RE_QUOTATION = /(?:^"|"$)|(?:^'|'$)/g;


/**
 * WebFont 描述类
 * @param   {object}
 */
function WebFont(options) {
    this.id = options.id;
    this.family = options.family;
    this.files = options.files;
    this.stretch = options.stretch;
    this.style = options.style;
    this.weight = options.weight;

    this.chars = options.chars || '';
    this.selectors = options.selectors || [];
    this.elements = options.elements || [];
}


/**
 * 解析 @font-face
 * @param   {CSSFontFaceRule}
 * @return  {WebFont, null}
 */
WebFont.parse = function parseFontFace(cssFontFaceRule) {

    var ruleStyle = cssFontFaceRule.style;
    var parentStyleSheet = cssFontFaceRule.parentStyleSheet;

    // <link> || <style>
    var baseURI = parentStyleSheet.href || parentStyleSheet.ownerNode.baseURI;


    var family = ruleStyle['font-family'];
    var stretch = ruleStyle['font-stretch'];
    var style = ruleStyle['font-style'];
    var weight = ruleStyle['font-weight'];

    if (!family) {
        return null;
    }

    var src = ruleStyle.src;
    var files = WebFont.getFiles(src, baseURI);


    if (!files.length) {
        return null;
    }


    family = family.replace(RE_QUOTATION, '');

    var id = crypto
        .createHash('md5')
        .update(family + files.join(','))
        .digest('hex');

    return new WebFont({
        id: id,
        family: family,
        files: files,
        stretch: stretch,
        style: style,
        weight: weight
    });
};


WebFont.prototype = {


    constructor: WebFont,


    /**
     * 匹配 CSS 规则
     * @see https://www.w3.org/html/ig/zh/wiki/CSS3字体模块#.E5.AD.97.E4.BD.93.E5.8C.B9.E9.85.8D.E7.AE.97.E6.B3.95
     * @param   {CSSStyleDeclaration}
     * @return  {Boolean}
     */
    matchStyle: function(style) {

        var fontFamilys = WebFont.getComputedFontFamilys(style);

        // 虽然仅使用字体名称来匹配会可能产生冗余，但比较安全
        // TODO 完善匹配算法 fontFamily | fontStretch | fontStyle | fontWeight
        return fontFamilys.indexOf('"' + this.family + '"') !== -1;
    },



    /**
     * 匹配元素节点
     * @param   {HTMLElement}
     * @return  {Boolean}
     */
    matchElement: function(element) {
        var elements = this.elements;

        if (!elements || !elements.length) {
            return false;
        }

        while (element) {
            if (elements.indexOf(element) !== -1) {
                return true;
            }
            element = element.parentNode;
        }

        return false;
    },


    /**
     * 添加字符
     * @param   {String}
     */
    addChar: function(char) {
        if (this.chars.indexOf(char) === -1) {
            this.chars += char;
        }
    },


    /**
     * 添加选择器
     * @param   {String}
     */
    addSelector: function(selector) {
        if (this.selectors.indexOf(selector) === -1) {
            this.selectors.push(selector);
        }
    },


    /**
     * 添加元素
     * @param   {String}
     */
    addElement: function(element) {
        if (this.elements.indexOf(element) === -1) {
            this.elements.push(element);
        }
    },


    /**
     * 转换为数据
     * @return   {Object}
     */
    toData: function() {
        return {
            id: this.id,
            family: this.family,
            files: this.files,
            stretch: this.stretch,
            style: this.style,
            weight: this.weight,
            chars: this.chars,
            selectors: this.selectors
        };
    }

};



/**
 * 获取当前 CSSStyleDeclaration 计算后的 font-family
 * @TODO    CSSOM 模块的重名 key + !important BUG 修复
 * @param   {CSSStyleDeclaration}
 * @return  {Array<String>}
 */
WebFont.getComputedFontFamilys = function(style) {
    if (!style['font-family'] && !style.font) {
        return [];
    }

    var key, ast, important, fontFamilys;
    var index = -1;
    var length = style.length;

    while (++index < length) {
        key = style[index];

        if (key === 'font-family') {
            setFontFamilys(key, style[key]);
        } else if (key === 'font') {
            ast = cssFontParser(style[key]);

            if (ast) {
                setFontFamilys(key, ast['font-family'].join(','));
            }
        }
    }


    function setFontFamilys(key, value) {
        var propertyPriority = style.getPropertyPriority(key);
        if (propertyPriority || !important || !fontFamilys) {
            fontFamilys = WebFont.getFontFamilys(value);
        }
        important = propertyPriority;
    }


    if (!fontFamilys || fontFamilys[0] === 'inherit') {
        fontFamilys = [];
    }

    return fontFamilys;
};


/**
 * 标准化 font-family 值，给非关键字都加上双引号
 * @param   {String}    font-family
 * @return  {Array<String>}
 */
WebFont.getFontFamilys = function(input) {
    return WebFont.split(input).map(function(fontFamily) {
        if (KEYWORDS.indexOf(fontFamily) !== -1) {
            return fontFamily;
        } else {
            return '"' + fontFamily.replace(RE_QUOTATION, '') + '"';
        }
    });
};


/**
 * 按逗号切割 font-family 值
 * @param   {String}    font-family
 * @return  {Array<String>}
 */
WebFont.split = function(fontFamily) {
    return utils.split(fontFamily).map(function(fontFamily) {
        return fontFamily.trim();
    });
};


/**
 * 解析 @font-face src 值
 * @param   {String}    src 值
 * @param   {String}    基础路径
 * @param   {Array<WebFont.File>}
 */
WebFont.getFiles = function(input, baseURI) {
    var list = [];
    var src;

    var RE_FONT_URL = /url\(("|')?(.*?)\1?\)(?:\s*format\(("|')?(.*?)\3?\))?/ig;

    RE_FONT_URL.lastIndex = 0;

    while ((src = RE_FONT_URL.exec(input)) !== null) {
        list.push(new WebFont.File(src[2], src[4], baseURI));
    }

    return list;
};


/**
 * font-face 路径描述信息类
 * @param   {String}    地址
 * @param   {String}    格式
 * @param   {String}    基础路径
 */
WebFont.File = function(url, format, baseURI) {

    var RE_SERVER = /^https?\:\/\//i;

    if (!RE_SERVER.test(url)) {
        url = nodeUrl.resolve(baseURI, url);
    }

    if (RE_SERVER.test(url)) {
        url = url.replace(/[#].*$/, '');
    } else {
        url = url.replace(/[?#].*$/, '');
    }

    if (!format) {
        switch (nodePath.extname(url.replace(/\?.*$/, '')).toLowerCase()) {
            case '.eot':
                format = 'embedded-opentype';
                break;
            case '.woff2':
                format = 'woff2';
                break;
            case '.woff':
                format = 'woff';
                break;
            case '.ttf':
                format = 'truetype';
                break;
            case '.otf':
                format = 'opentype';
                break;
            case '.svg':
                format = 'svg';
                break;
        }
    } else {
        format = format.toLowerCase();
    }

    this.url = decodeURIComponent(url);
    this.format = format;
};

WebFont.File.prototype.toString = function() {
    return this.url;
};


module.exports = WebFont;
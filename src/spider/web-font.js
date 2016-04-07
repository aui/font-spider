'use strict';

var path = require('path');
var url = require('url');
var crypto = require('crypto');
var cssFontParser = require('css-font-parser');


/**
 * FontFace 描述类
 * @param   {object}
 */
function FontFace(options) {
    this.id = options.id;
    this.family = options.family;
    this.files = options.files;
    this.stretch = options.stretch;
    this.style = options.style;
    this.weight = options.weight;
}


/**
 * 解析 @font-face
 * @param   {CSSFontFaceRule}
 * @return  {FontFace}
 */
FontFace.parse = function parseFontFace(cssFontFaceRule) {
    var baseURI = cssFontFaceRule.parentStyleSheet.href;
    var s = cssFontFaceRule.style;

    var family = s['font-family'];
    var stretch = s['font-stretch'];
    var style = s['font-style'];
    var weight = s['font-weight'];

    var src = s.src;
    var files = parseFontFaceSrc(src, baseURI);

    if (!family) {
        return null;
    }

    family = parseFontfamily(family)[0];

    var id = crypto
        .createHash('md5')
        .update(files.join(','))
        .digest('hex');

    return new FontFace({
        id: id,
        family: family,
        files: files,
        stretch: stretch,
        style: style,
        weight: weight
    });
};



/**
 * 匹配 CSS 规则
 * @see https://www.w3.org/html/ig/zh/wiki/CSS3字体模块#.E5.AD.97.E4.BD.93.E5.8C.B9.E9.85.8D.E7.AE.97.E6.B3.95
 * @param   {CSSStyleDeclaration}
 * @return  {Boolean}
 */
FontFace.prototype.match = function(style) {

    var fontFamilys = [];

    if (!style['font-family'] && !style.font) {
        return false;
    }

    for (var i = 0, key; i < style.length; i++) {
        key = style[i];

        if (key === 'font-family') {
            fontFamilys = parseFontfamily(style[key]);
        } else if (key === 'font') {
            var s = cssFontParser(style[key]);
            if (s) {
                var f = s['font-family'];
                if (Array.isArray(f)) {
                    fontFamilys = f;
                }
            }
        }
    }

    // 暂时只能做到名称匹配，会产生冗余
    // TODO 完善匹配算法 fontFamily | fontStretch | fontStyle | fontWeight
    if (fontFamilys.indexOf(this.family) !== -1) {
        return true;
    } else {
        return false;
    }
};



// 解析 @font-face src 值
function parseFontFaceSrc(value, baseURI) {
    var list = [];
    var src;

    var RE_FONT_URL = /url\(["']?(.*?)["']?\)(?:\s*format\(["']?(.*?)["']?\))?/ig;

    RE_FONT_URL.lastIndex = 0;

    while ((src = RE_FONT_URL.exec(value)) !== null) {
        list.push(new FontFile(baseURI, src[1], src[2]));
    }

    return list;
}



// font-face 路径与字体类型描述信息类
function FontFile(baseURI, source, format) {

    if (baseURI) {
        source = url.resolve(baseURI, source);
    }

    source = source.replace(/[\?#].*$/, '');

    if (!format) {

        switch (path.dirname(source).toLowerCase()) {
            case '.eot':
                format = 'embedded-opentype';
                break;
            case '.woff':
                format = 'woff';
                break;
            case '.ttf':
                format = 'truetype';
                break;
            case '.svg':
                format = 'svg';
                break;
        }
    } else {
        format = format.toLowerCase();
    }

    this.source = source;
    this.format = format;
}

FontFile.prototype.toString = function() {
    return this.source;
};



// 解析 font-family 属性值为数组
function parseFontfamily(fontFamily) {
    // TODO test
    var list = fontFamily
        .replace(/^\s*["']?|["']?\s*$|["']?\s*(,)\s*["']?/g, '$1')
        .split(',');
    return list;
}


/**
 * WebFont 描述类 - 继承自 FontFace
 * @param   {object}
 */
function WebFont(options) {
    FontFace.call(this, options);
    this.chars = '';
    this.selectors = [];
}

WebFont.parse = function(cssFontFaceRule) {
    return new WebFont(FontFace.parse(cssFontFaceRule));
};
WebFont.prototype = Object.create(FontFace.prototype);
WebFont.prototype.constructor = WebFont;


module.exports = WebFont;
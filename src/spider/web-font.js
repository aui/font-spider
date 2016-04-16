'use strict';

var path = require('path');
var url = require('url');
var crypto = require('crypto');
var cssFontParser = require('css-font-parser');
var utils = require('./utils');


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
}


/**
 * 解析 @font-face
 * @param   {CSSFontFaceRule}
 * @return  {WebFont, null}
 */
WebFont.parse = function parseFontFace(cssFontFaceRule) {

    var s = cssFontFaceRule.style;
    var parentStyleSheet = cssFontFaceRule.parentStyleSheet;

    // <link> || <style>
    var baseURI = parentStyleSheet.href || parentStyleSheet.ownerNode.baseURI;


    var family = s['font-family'];
    var stretch = s['font-stretch'];
    var style = s['font-style'];
    var weight = s['font-weight'];

    if (!family) {
        return null;
    }

    var src = s.src;
    var files = parseFontFaceSrc(src, baseURI);


    if (!files.length) {
        return null;
    }


    family = parseFontfamily(family)[0];

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



WebFont.FontFile = FontFile;
WebFont.parseFontFaceSrc = parseFontFaceSrc;
WebFont.parseFontfamily = parseFontfamily;


/**
 * 匹配 CSS 规则
 * @see https://www.w3.org/html/ig/zh/wiki/CSS3字体模块#.E5.AD.97.E4.BD.93.E5.8C.B9.E9.85.8D.E7.AE.97.E6.B3.95
 * @param   {CSSStyleDeclaration}
 * @return  {Boolean}
 */
WebFont.prototype.match = function(style) {

    var fontFamilys = [];

    if (!style['font-family'] && !style.font) {
        return false;
    }

    var key;
    var index = -1;
    var length = style.length;

    while (++index < length) {
        key = style[index];
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


    // 虽然仅使用字体名称来匹配会可能产生冗余，但能能避免压缩后缺少字形的问题
    // TODO 完善匹配算法 fontFamily | fontStretch | fontStyle | fontWeight
    if (fontFamilys.indexOf(this.family) !== -1) {
        return true;
    } else {
        return false;
    }
};



/**
 * 解析 @font-face src 值
 * @param   {String}    src 值
 * @param   {String}    基础路径
 * @param   {Array<FontFile>}
 */
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


/**
 * 解析 font-family 值
 * @param   {String}
 * @return  {Array<String>}
 */
function parseFontfamily(fontFamily) {
    return utils.split(fontFamily).map(function(value) {
        return value.replace(/^["']|["']$/g, '');
    });
}


/**
 * font-face 路径描述信息类
 * @param   {String}    基础路径
 * @param   {String}    地址
 * @param   {String}    格式
 */
function FontFile(baseURI, source, format) {

    var RE_SERVER = /^https?\:\/\//i;

    if (!RE_SERVER.test(source)) {
        source = url.resolve(baseURI, source);
    }

    if (RE_SERVER.test(source)) {
        source = source.replace(/[#].*$/, '');
    } else {
        source = source.replace(/[?#].*$/, '');
    }

    if (!format) {
        switch (path.extname(source.replace(/\?.*$/, '')).toLowerCase()) {
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



module.exports = WebFont;
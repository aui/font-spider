'use strict';

var crypto = require('crypto');
var parsers = require('./parsers');


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
    var files = parsers.cssFontFaceSrcParser(src, baseURI);


    if (!files.length) {
        return null;
    }


    family = parsers.cssFontfamilyParser(family)[0];

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
    var cfp, fs;

    while (++index < length) {
        key = style[index];
        if (key === 'font-family') {
            fontFamilys = parsers.cssFontfamilyParser(style[key]);
        } else if (key === 'font') {
            try {
                cfp = parsers.cssFontParser(style[key]);
            } catch(e) {}

            if (cfp) {
                fs = cfp['font-family'];
                if (Array.isArray(fs)) {
                    fontFamilys = fs;
                }
            }
        }
    }


    // 虽然仅使用字体名称来匹配会可能产生冗余，但比较安全
    // TODO 完善匹配算法 fontFamily | fontStretch | fontStyle | fontWeight
    if (fontFamilys.indexOf(this.family) !== -1) {
        return true;
    } else {
        return false;
    }
};



module.exports = WebFont;
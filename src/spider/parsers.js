'use strict';
var cssFontParser = require('css-font-parser');
var nodeUrl = require('url');
var nodePath = require('path');



/**
 * 按 /\s?,\s?/ 分割字符串
 * @param   {String}
 * @return  {Array<String>}
 * @example
 *      split('.class, [data-name=",\\""], .class2')
 *      >>>     ['.class', '[data-name=",\\""]', '.class2']
 *
 *      split('Arial, Helvetica, "Microsoft Yahei"')
 *      >>>     ['Arial', 'Helvetica', '"Microsoft Yahei"']
 */
function split(input) {

    var current = 0;
    var array = [];
    var length = input.length;
    var char, value, quotation;
    var SPLIT = /,/;
    var WHITESPACE = /\s/;
    var STRING = /["']/;

    while (current < length) {

        char = input.charAt(current);

        // 分割符
        if (SPLIT.test(char)) {
            add('', true);
            current++;
            continue;
        }

        // 空白
        if (WHITESPACE.test(char)) {
            current++;
            continue;
        }

        // 字符串
        if (STRING.test(char)) {
            quotation = char;
            value = quotation;

            while (current < length) {
                char = input.charAt(++current);
                value += char;

                if (char === '\\') {
                    value += input.charAt(++current);
                    continue;
                }

                if (char === quotation) {
                    break;
                }
            }

            add(value);
            current++;
            continue;
        }

        // 其他
        add(char);
        current++;
    }


    function add(char, split) {
        if (split || array.length === 0) {
            array.push('');
        }
        array[array.length - 1] += char;
    }


    return array;
}



/**
 * 解析伪元素 content 值
 * 仅支持 `content: 'prefix'` 和 `content: attr(value)` 这两种或组合的形式
 * @see https://developer.mozilla.org/zh-CN/docs/Web/CSS/content
 * @param   {String}
 * @return  {Array}
 */
function cssContentParser(input) {

    var tokens = tokenizer(input);

    var ret = [];
    var length = tokens.length;
    var current = 0;
    var token, open, close;

    while (current < length) {
        token = tokens[current];

        if (token.type === 'string') {
            ret.push({
                type: 'string',
                value: parseString(token.value)
            });
            current++;
            continue;
        }

        if (token.type === 'word' && /^attr$/i.test(token.value)) {

            open = tokens[current + 1];
            token = tokens[current + 2];
            close = tokens[current + 3];

            if ((open.type === 'symbol' && open.value === '(') &&
                (token.type === 'word' && /^[\w\-]*$/.test(token.value)) &&
                (close.type === 'symbol' && close.value === ')')) {
                ret.push({
                    type: 'attr',
                    value: token.value
                });
                current += 4;
                continue;
            } else {
                throw new SyntaxError('attr' + open.value + token.value + close.value);
            }
        }

        current++;
    }

    // `sss\"` >>> `sss"`
    function parseString(input) {
        input = input.replace(/(?:^"|"$)|(?:^'|'$)/g, '');
        var current = 0;
        var length = input.length;
        var value = '';
        var char;

        while (current < length) {
            char = input.charAt(current);
            if (char === '\\') {
                value += input.charAt(++current);
            } else {
                value += char;
            }
            current++;
        }

        return value;
    }

    return ret;
}




/**
 * 解析 font-family 值
 * @param   {String}
 * @return  {Array<String>}
 */
function cssFontfamilyParser(input) {
    return split(input).map(function(value) {
        return value.replace(/(?:^"|"$)|(?:^'|'$)/g, '');
    });
}


/**
 * 获取 CSS value 的 tokens
 * @param   {String}
 * @return  {Array}
 */
function tokenizer(input) {
    var current = 0;
    var tokens = [];
    var length = input.length;
    var STRING = /["']/;
    var WHITESPACE = /\s/;
    var SYMBOL = /[(),/]/;
    var WORDS = /[^"'\s(),/]/;
    var quotation, value, char;

    while (current < length) {
        char = input[current];

        if (SYMBOL.test(char)) {
            tokens.push({
                type: 'symbol',
                value: char
            });

            current++;
            continue;
        }

        if (WHITESPACE.test(char)) {
            current++;
            continue;
        }

        if (STRING.test(char)) {
            quotation = char;
            value = quotation;

            while (current < length) {
                char = input.charAt(++current);
                value += char;

                if (char === '\\') {
                    value += input.charAt(++current);
                    continue;
                }

                if (char === quotation) {
                    break;
                }
            }

            tokens.push({
                type: 'string',
                value: value
            });

            current++;
            continue;
        }

        if (WORDS.test(char)) {
            value = '';

            while (WORDS.test(char)) {
                value += char;
                char = input[++current];
            }

            tokens.push({
                type: 'word',
                value: value
            });

            continue;
        }

        current++;
        throw new TypeError('Unexpected identifier: ' + char);
    }

    return tokens;
}



/**
 * 解析 @font-face src 值
 * @param   {String}    src 值
 * @param   {String}    基础路径
 * @param   {Array<FontFile>}
 */
function cssFontFaceSrcParser(input, baseURI) {
    var list = [];
    var src;

    var RE_FONT_URL = /url\(("|')?(.*?)\1?\)(?:\s*format\(("|')?(.*?)\3?\))?/ig;

    RE_FONT_URL.lastIndex = 0;

    while ((src = RE_FONT_URL.exec(input)) !== null) {
        list.push(new FontFile(baseURI, src[2], src[4]));
    }

    return list;
}

cssFontFaceSrcParser.FontFile = FontFile;


/**
 * font-face 路径描述信息类
 * @param   {String}    基础路径
 * @param   {String}    地址
 * @param   {String}    格式
 */
function FontFile(baseURI, url, format) {

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
            case '.svg':
                format = 'svg';
                break;
        }
    } else {
        format = format.toLowerCase();
    }

    this.url = url;
    this.format = format;
}

FontFile.prototype.toString = function() {
    return this.url;
};



module.exports = {
    split: split,
    tokenizer: tokenizer,
    cssFontParser: cssFontParser,
    cssContentParser: cssContentParser,
    cssFontfamilyParser: cssFontfamilyParser,
    cssFontFaceSrcParser: cssFontFaceSrcParser,
};
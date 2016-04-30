'use strict';
var cssFontParser = require('css-font-parser');
module.exports = {

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
    split: function(input) {

        // 使用正则无法通过测试用例
        // var RE_SPLIT_GROUP = /([^,\\()[\]]+|\[[^[\]]*\]|\[.*\]|\([^()]+\)|\(.*\)|\{[^{}]+\}|\{.*\}|\\.)+/g;
        // return input.match(RE_SPLIT_GROUP).map(function(value) {
        //     return value.trim();
        // });

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
    },

    /**
     * 解析伪元素 content 值
     * 仅支持 `content: 'prefix'` 和 `content: attr(value)` 这两种或组合的形式
     * @see https://developer.mozilla.org/zh-CN/docs/Web/CSS/content
     * @param   {String}
     * @return  {Array}
     */
    cssContentParser: function(input) {

        // var exec, value;
        // var tokens = [];

        // var RE_CONTENT = /("(?:\\"|[^"])*"|'(?:\\'|[^']*)'|\battr\([^\)]*\))/ig;
        // var RE_STRING = /^("|')(.*)\1$/;
        // var RE_ATTR = /^attr\(([^\)]*)\)$/i;

        // RE_CONTENT.lastIndex = 0;

        // while ((exec = RE_CONTENT.exec(input)) !== null) {
        //     if (value = exec[0].match(RE_STRING)) {
        //         tokens.push({
        //             type: 'string',
        //             value: parseString(value[2])
        //         });
        //     } else if (value = exec[0].match(RE_ATTR)) {
        //         tokens.push({
        //             type: 'attr',
        //             value: value[1]
        //         });
        //     }
        // }

        // return tokens;

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

            if (token.type === 'name' && /^attr$/i.test(token.value)) {

                open = tokens[current + 1];
                token = tokens[current + 2];
                close = tokens[current + 3];

                if ((open.type === 'paren' && open.value === '(') &&
                    (token.type === 'name') &&
                    (close.type === 'paren' && close.value === ')')) {
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
    },

    cssFontParser: cssFontParser
};

// 将 css conent 解析为 tokens
function tokenizer(input) {
    var current = 0;
    var tokens = [];
    var length = input.length;
    var STRING = /["']/;
    var WHITESPACE = /\s/;
    var LETTERS = /[\w\-]/;
    var quotation, value, char;

    while (current < length) {
        char = input[current];

        if (char === '(') {

            tokens.push({
                type: 'paren',
                value: '('
            });

            current++;
            continue;
        }

        if (char === ')') {
            tokens.push({
                type: 'paren',
                value: ')'
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

        if (LETTERS.test(char)) {
            value = '';

            while (LETTERS.test(char)) {
                value += char;
                char = input[++current];
            }

            tokens.push({
                type: 'name',
                value: value
            });

            continue;
        }

        current++;
        throw new TypeError('Unexpected identifier: ' + char);
    }

    return tokens;
}

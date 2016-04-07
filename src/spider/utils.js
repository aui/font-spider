'use strict';

module.exports = {
    // '.class, [data-name=",\""], .class2'
    // >>> ['.class', '[data-name=",\""]', '.class2']
    split: function(string, splitChar) {

        splitChar = splitChar || ',';

        var char;
        var array = [];
        var index = -1;
        var length = string.length;
        var on = null;
        var escapeChar = '\\';
        var RE_BLANK = /[\s\n\r\t]/;
        var quotationChars = {
            '"': '"',
            "'": "'"
        };


        while (++index < length) {
            char = string.charAt(index);

            if (on) {
                if (char === on && string.charAt(index - 1) !== escapeChar) {
                    on = null;
                }
                array[array.length - 1] += char;
            } else {
                if (char === splitChar) {
                    array.push('');
                } else {
                    if (quotationChars[char]) {
                        on = quotationChars[char];
                    }

                    if (!array.length) {
                        array.push('');
                    }

                    if (!RE_BLANK.test(char)) {
                        array[array.length - 1] += char;
                    }
                }
            }
        }


        return array;
    }
};
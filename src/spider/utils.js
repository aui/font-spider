'use strict';

module.exports = {

    /**
     * 按 /\s?,\s?/ 分割字符串
     * @param   {String}
     * @return  {Array<String>}
     * split('.class, [data-name=",\\""], .class2')
     * ['.class', '[data-name=",\\""]', '.class2']
     */
    split: function(string) {

        var char;
        var array = [];
        var index = -1;
        var length = string.length;
        var stringMode = null;
        var splitChar = ',';
        var escapeChar = '\\';
        var RE_BLANK = /\s/;
        var quotationChars = {
            '"': '"',
            "'": "'"
        };


        while (++index < length) {
            // 当前字符
            char = string.charAt(index);

            // 字符串模式
            if (stringMode) {

                // 如果遇到字符串标识符且没有被反斜杠转义则关闭字符串模式
                if (char === stringMode && string.charAt(index - 1) !== escapeChar) {
                    stringMode = null;
                }

                // 向队列最后一项存入任意字符
                array[array.length - 1] += char;

                // 非字符串模式
            } else {

                // 遇到分割标示符则切割
                if (char === splitChar) {
                    array.push('');
                } else {

                    // 如果遇到字符串标识符则开启字符串模式
                    if (quotationChars[char]) {
                        stringMode = quotationChars[char];
                    }

                    if (!array.length) {
                        array.push('');
                    }

                    // 向队列最后一项存入非空字符
                    if (!RE_BLANK.test(char)) {
                        array[array.length - 1] += char;
                    }
                }
            }
        }


        return array;
    }
};

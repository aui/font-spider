'use strict';

var assert = require('assert');
var fontSpider = require('../src/spider');

describe('fontSpider', function() {
    it('fontSpider', function() {
        return fontSpider([__dirname + '/files/01.html', __dirname + '/files/02.html'], {
            silent: false
        }).then(function(webFonts) {
            var testChars = {
                'webfont-a': ['字', '代', '码', '如', '诗', '美', '丽', '@'],
                'webfont-b': ['方', '块', '字', '中', '文', '大', '海'],
                'webfont-c': ['蛛', '@'],
                'webfont-e': ['厦', '门']
            };

            function unequal(family, chars) {
                var list = testChars[family];
                var index = -1;
                var length = list.length;
                var unequal = [];
                while (++index < length) {
                    if (chars.indexOf(list[index]) === -1) {
                        unequal.push(list[index]);
                    }
                }
                return unequal;
            }

            return webFonts.map(function(webFont) {
                var list = unequal(webFont.family, webFont.chars);
                if (list.length) {
                    throw new Error(webFont.family + ' unequal: ' + list);
                } else {
                    return webFont;
                }
            });
        });
    });
});
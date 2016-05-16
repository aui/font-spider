'use strict';

var assert = require('assert');
var spider = require('../src/spider');
var fs = require('fs');

describe('spider', function() {

    it('selectors', function() {
        var htmlFiles = [__dirname + '/files/selectors.html'];
        return spider(htmlFiles, {
            silent: false
        }).then(function(webFonts) {
            assert.equal('abcdefg', webFonts[0].chars);
            return webFonts;
        });
    });

    it('css content', function() {
        var htmlFiles = [__dirname + '/files/parse-element-content.html'];
        return spider(htmlFiles, {
            silent: false
        }).then(function(webFonts) {
            assert.equal(' "你大好海糖饼🍎', webFonts[0].chars);
            return webFonts;
        });
    });

    it('html content + css content', function() {
        var htmlFiles = [__dirname + '/files/01.html', __dirname + '/files/02.html'];
        return spider(htmlFiles, {
            silent: false
        }).then(done);
    });

    it('gulp: html content + css content', function() {
        var htmlFiles = [__dirname + '/files/01.html', __dirname + '/files/02.html'];
        return spider(htmlFiles.map(function(file) {
            return {
                path: file,
                contents: fs.readFileSync(file)
            }
        }), {
            silent: false
        }).then(done);
    });

    function done(webFonts) {

        var testChars = {
            'webfont-a': ['字', '代', '码', '如', '诗', '美', '丽', '@'],
            'webfont-b': ['方', '块', '字', '中', '文', '大', '海', '🍎', ' '],
            'webfont-c': ['蛛', '@'],
            'webfont-e': ['❤', '厦', '门'],
            length: 4
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
                throw new Error(webFont.family + ' not included: ' + list);
            } else {
                return webFont;
            }
        });
    }
});
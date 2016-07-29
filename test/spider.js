'use strict';

var assert = require('assert');
var spider = require('../src/spider');
var fs = require('fs');

describe('spider', function() {

    it('selectors', function() {
        var htmlFiles = [__dirname + '/files/index.html'];
        return spider(htmlFiles, {
            silent: false
        }).then(function(webFonts) {

            assert.equal('a', webFonts[0].family);
            assert.equal('abc', webFonts[0].chars);
            assert.deepEqual([
                '#font-a .basic-element',
                '#font-a .pseudo-element::before',
                '#font-a .pseudo-element::after'
            ], webFonts[0].selectors);


            assert.equal('b', webFonts[1].family);
            assert.equal('abc', webFonts[1].chars);
            assert.deepEqual([
                '#font-b .basic-element',
                '#font-b .pseudo-element::before',
                '#font-b .pseudo-element::after'
            ], webFonts[1].selectors);


            assert.equal('c', webFonts[2].family);
            assert.equal(' abcd', webFonts[2].chars);
            assert.deepEqual([
                '#font-c:hover .basic-element',
                '#font-c:focus .pseudo-element::before',
                '#font-c .pseudo-element:hover::after'
            ], webFonts[2].selectors);


            assert.equal('d', webFonts[3].family);
            assert.equal('abc', webFonts[3].chars);
            assert.deepEqual(['#font-d .basic-element'], webFonts[3].selectors);


            assert.equal('e', webFonts[4].family);
            assert.equal(' abcd', webFonts[4].chars);
            assert.deepEqual([
                '#font-e',
                '#font-e .pseudo-element::before',
                '#font-e .pseudo-element::after'
            ], webFonts[4].selectors);


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

    it('input placeholder', function() {
        var htmlFiles = [__dirname + '/files/input-placeholder.html'];
        return spider(htmlFiles, {
            silent: false
        }).then(function(webFonts) {
            assert.equal('abcde', webFonts[0].chars);
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
'use strict';

var WebFont = require('../src/spider/web-font.js');
var assert = require('assert');
var cssom = require('cssom');
var CSSStyleDeclaration = cssom.CSSStyleDeclaration;

describe('WebFont', function() {


    describe('#split', function() {
        it('serif', function() {
            assert.deepEqual(['serif'], WebFont.split('serif'));
        });
        it('web-font-a, web-font-b, web-font-c', function() {
            assert.deepEqual(['web-font-a', 'web-font-b', 'web-font-c'], WebFont.split('web-font-a, web-font-b, web-font-c'));
        });
        it('web-font-a, "web-font,b"', function() {
            assert.deepEqual(['web-font-a', '"web-font,b"'], WebFont.split('web-font-a, "web-font,b"'));
        });
    });

    describe('#getFontFamilys', function() {
        it('serif', function() {
            assert.deepEqual(['serif'], WebFont.getFontFamilys('serif'));
        });
        it('serif, "Helvetica"', function() {
            assert.deepEqual(['serif', '"Helvetica"'], WebFont.getFontFamilys('serif, "Helvetica"'));
        });
        it('serif, "Helvetica",  \'Microsoft Yahei\'', function() {
            assert.deepEqual(['serif', '"Helvetica"', '"Microsoft Yahei"'], WebFont.getFontFamilys('serif, "Helvetica",  \'Microsoft Yahei\''));
        });
        it('serif, "Helvetica mini"', function() {
            assert.deepEqual(['serif', '"Helvetica mini"'], WebFont.getFontFamilys('serif, "Helvetica mini"'));
        });
        it('serif, "Helvetica, mini"', function() {
            assert.deepEqual(['serif', '"Helvetica, mini"'], WebFont.getFontFamilys('serif, "Helvetica, mini"'));
        });
        it('serif, ",\\"Helvetica, mini,\\"', function() {
            assert.deepEqual(['serif', '",\\"Helvetica, mini,\\""'], WebFont.getFontFamilys('serif, ",\\"Helvetica, mini,\\""'));
        });
    });


    describe('#getFontFamilys', function() {
        it('web-font-a', function() {
            assert.deepEqual(['"web-font-a"'], WebFont.getFontFamilys('web-font-a'));
        });
        it("web-font-a", function() {
            assert.deepEqual(['"web-font-a"'], WebFont.getFontFamilys('"web-font-a"'));
        });
        it("web-font-a", function() {
            assert.deepEqual(['"web-font-a"'], WebFont.getFontFamilys('\'web-font-a\''));
        });
        it('serif, sans-serif, monospace, cursive, fantasy', function() {
            assert.deepEqual(['serif', 'sans-serif', 'monospace', 'cursive', 'fantasy'], WebFont.getFontFamilys('serif, sans-serif, monospace, cursive, fantasy'));
        });
        it('inherit', function() {
            assert.deepEqual(['inherit'], WebFont.getFontFamilys('inherit'));
        });
        it('web-font-a, "web-font-b",  \'web-font-c\',web-font-d, serif', function() {
            assert.deepEqual(['"web-font-a"', '"web-font-b"', '"web-font-c"', '"web-font-d"', 'serif'], WebFont.getFontFamilys('web-font-a, "web-font-b",  \'web-font-c\',web-font-d, serif'));
        });
    });


    describe('#getComputedFontFamilys', function() {
        it('font-family: web-font-a', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: web-font-a';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font-family: web-font-a, web-font-b, serif', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: web-font-a, web-font-b, serif';
            assert.deepEqual(['"web-font-a"', '"web-font-b"', 'serif'], WebFont.getComputedFontFamilys(style));
        });
        it('font-family: \'web-font-a\'', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: \'web-font-a\'';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font-family: "web-font-a"', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: "web-font-a"';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font: 16px web-font-a', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font: 16px web-font-a';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font: 16px \'web-font-a\'', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font: 16px \'web-font-a\'';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font: 16px "web-font-a"', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font: 16px "web-font-a"';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font-family: web-font-a; font:16px web-font-b', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: web-font-a; font:16px web-font-b';
            assert.deepEqual(['"web-font-b"'], WebFont.getComputedFontFamilys(style));
        });
        it('font-family: web-font-a!important; font:16px web-font-b', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: web-font-a!important; font:16px web-font-b';
            assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        });
        it('font-family: inherit', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = 'font-family: inherit';
            assert.deepEqual([], WebFont.getComputedFontFamilys(style));
        });
        // 不支持大写
        // it('FONT-FAMILY: web-font-a', function() {
        //     var style = new CSSStyleDeclaration();
        //     style.cssText = 'FONT-FAMILY: web-font-a';
        //     assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        // });
        // it('FONT: 16px web-font-a', function() {
        //     var style = new CSSStyleDeclaration();
        //     style.cssText = 'FONT: 16px web-font-a';
        //     assert.deepEqual(['"web-font-a"'], WebFont.getComputedFontFamilys(style));
        // });
        it('<no font-family>', function() {
            var style = new CSSStyleDeclaration();
            style.cssText = '';
            assert.deepEqual([], WebFont.getComputedFontFamilys(style));
        });
    });


    describe('#File', function() {
        it('toString()', function() {
            assert.deepEqual('/Document/font/test.ttf', (new WebFont.File(
                '../font/test.ttf',
                null,
                '/Document/css/style.css'
            )).toString());
        });
        it('format: truetype', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'truetype'
            }, new WebFont.File(
                '../font/test.ttf',
                null,
                '/Document/css/style.css'
            ));
        });
        it('format: woff2', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff2',
                format: 'woff2'
            }, new WebFont.File(
                '../font/test.woff2',
                null,
                '/Document/css/style.css'
            ));
        });
        it('format: woff', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff',
                format: 'woff'
            }, new WebFont.File(
                '../font/test.woff',
                null,
                '/Document/css/style.css'
            ));
        });
        it('format: embedded-opentype', function() {
            assert.deepEqual({
                url: '/Document/font/test.eot',
                format: 'embedded-opentype'
            }, new WebFont.File(
                '../font/test.eot',
                null,
                '/Document/css/style.css'
            ));
        });
        it('format: svg', function() {
            assert.deepEqual({
                url: '/Document/font/test.svg',
                format: 'svg'
            }, new WebFont.File(
                '../font/test.svg',
                null,
                '/Document/css/style.css'
            ));
        });
        it('set format: truetype', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'truetype'
            }, new WebFont.File(
                '../font/test.ttf',
                'truetype',
                '/Document/css/style.css'
            ));
        });
        it('set format: woff', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'woff'
            }, new WebFont.File(
                '../font/test.ttf',
                'woff',
                '/Document/css/style.css'
            ));
        });
        it('local file', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff2',
                format: 'woff2'
            }, new WebFont.File(
                '../font/test.woff2?v=3#sfdsfs',
                null,
                '/Document/css/style.css'
            ));
        });
        it('local file2', function() {
            assert.deepEqual({
                url: '/font/test.woff2',
                format: 'woff2'
            }, new WebFont.File(
                '/font/test.woff2?v=3#sfdsfs',
                null,
                '/Document/css/style.css'
            ));
        });
        it('remote file', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.File(
                '../font/test.woff2?v=3#sfdsfs',
                null,
                'http://font-spider.org/css/style.css'
            ));
        });
        it('remote file2', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.File(
                '/font/test.woff2?v=3#sfdsfs',
                null,
                'http://font-spider.org/css/style.css'
            ));
        });
        it('remote file3', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.File(
                'http://font-spider.org/font/test.woff2?v=3#sfdsfs',
                null,
                '/Document/css/style.css'
            ));
        });
    });


    describe('#getFiles', function() {
        it("#1", function() {
            assert.deepEqual([{
                url: 'http://font.org/fonts/aui.woff2?v=4.5.0',
                format: 'woff2'
            }], WebFont.getFiles("url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "http://font.org/css/style.css"));
        });
        it('#2', function() {
            assert.deepEqual([{
                url: 'http://font.org/fonts/aui.eot?',
                format: 'embedded-opentype'
            }, {
                url: 'http://font.org/fonts/aui.woff2?v=4.5.0',
                format: 'woff2'
            }], WebFont.getFiles("url('../fonts/aui.eot?#iefix&v=4.5.0') format('embedded-opentype'), url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "http://font.org/css/style.css"));
        });
        it("#3", function() {
            assert.deepEqual([{
                url: '/Users/tangbin/fonts/aui.woff2',
                format: 'woff2'
            }], WebFont.getFiles("url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "/Users/tangbin/css/style.css"));
        });
        it("#4", function() {
            assert.deepEqual([{
                url: '/Users/tangbin/fonts/aui.eot',
                format: 'embedded-opentype'
            }], WebFont.getFiles("url('../fonts/aui.eot?#iefix&v=4.5.0') format('embedded-opentype')", "/Users/tangbin/css/style.css"));
        });
        it("#5", function() {
            assert.deepEqual([{
                url: '/Users/tangbin/fonts/aui.ttf',
                format: 'truetype'
            }], WebFont.getFiles("url('../fonts/aui.ttf?v=4.5.0')", "/Users/tangbin/css/style.css"));
        });
    });


});
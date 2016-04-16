'use strict';

var WebFont = require('../src/spider/web-font.js');
var assert = require('assert');

describe('WebFont', function() {

    describe('#parseFontfamily', function() {
        it('Arial', function() {
            assert.deepEqual(['Arial'], WebFont.parseFontfamily('Arial'));
        });
        it('Arial, "Helvetica"', function() {
            assert.deepEqual(['Arial', 'Helvetica'], WebFont.parseFontfamily('Arial, "Helvetica"'));
        });
        it('Arial, "Helvetica",  \'Microsoft Yahei\'', function() {
            assert.deepEqual(['Arial', 'Helvetica', 'Microsoft Yahei'], WebFont.parseFontfamily('Arial, "Helvetica",  \'Microsoft Yahei\''));
        });
        it('Arial, "Helvetica mini"', function() {
            assert.deepEqual(['Arial', 'Helvetica mini'], WebFont.parseFontfamily('Arial, "Helvetica mini"'));
        });
        it('Arial, "Helvetica, mini"', function() {
            assert.deepEqual(['Arial', 'Helvetica, mini'], WebFont.parseFontfamily('Arial, "Helvetica, mini"'));
        });
        it('Arial, ",\\"Helvetica, mini,\\"', function() {
            assert.deepEqual(['Arial', ',\\"Helvetica, mini,\\"'], WebFont.parseFontfamily('Arial, ",\\"Helvetica, mini,\\""'));
        });
    });

    describe('#FontFile', function() {
        it('toString()', function() {
            assert.deepEqual('/Document/font/test.ttf', (new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.ttf'
            )).toString());
        });
        it('format: truetype', function() {
            assert.deepEqual({
                source: '/Document/font/test.ttf',
                format: 'truetype'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.ttf'
            ));
        });
        it('format: woff2', function() {
            assert.deepEqual({
                source: '/Document/font/test.woff2',
                format: 'woff2'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.woff2'
            ));
        });
        it('format: woff', function() {
            assert.deepEqual({
                source: '/Document/font/test.woff',
                format: 'woff'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.woff'
            ));
        });
        it('format: embedded-opentype', function() {
            assert.deepEqual({
                source: '/Document/font/test.eot',
                format: 'embedded-opentype'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.eot'
            ));
        });
        it('format: svg', function() {
            assert.deepEqual({
                source: '/Document/font/test.svg',
                format: 'svg'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.svg'
            ));
        });
        it('set format: truetype', function() {
            assert.deepEqual({
                source: '/Document/font/test.ttf',
                format: 'truetype'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.ttf',
                'truetype'
            ));
        });
        it('set format: woff', function() {
            assert.deepEqual({
                source: '/Document/font/test.ttf',
                format: 'woff'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.ttf',
                'woff'
            ));
        });
        it('local file', function() {
            assert.deepEqual({
                source: '/Document/font/test.woff2',
                format: 'woff2'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '../font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('local file2', function() {
            assert.deepEqual({
                source: '/font/test.woff2',
                format: 'woff2'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                '/font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file', function() {
            assert.deepEqual({
                source: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.FontFile(
                'http://font-spider.org/css/style.css',
                '../font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file2', function() {
            assert.deepEqual({
                source: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.FontFile(
                'http://font-spider.org/css/style.css',
                '/font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file3', function() {
            assert.deepEqual({
                source: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.FontFile(
                '/Document/css/style.css',
                'http://font-spider.org/font/test.woff2?v=3#sfdsfs'
            ));
        });
    });

    describe('#parseFontFaceSrc', function() {
        it("#1", function() {
            assert.deepEqual([{
                source: 'http://font.org/fonts/aui.woff2?v=4.5.0',
                format: 'woff2'
            }], WebFont.parseFontFaceSrc("url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "http://font.org/css/style.css"));
        });
        it('#2', function() {
            assert.deepEqual([{
                source: 'http://font.org/fonts/aui.eot?',
                format: 'embedded-opentype'
            }, {
                source: 'http://font.org/fonts/aui.woff2?v=4.5.0',
                format: 'woff2'
            }], WebFont.parseFontFaceSrc("url('../fonts/aui.eot?#iefix&v=4.5.0') format('embedded-opentype'), url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "http://font.org/css/style.css"));
        });
        it("#3", function() {
            assert.deepEqual([{
                source: '/Users/tangbin/fonts/aui.woff2',
                format: 'woff2'
            }], WebFont.parseFontFaceSrc("url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "/Users/tangbin/css/style.css"));
        });
        it("#4", function() {
            assert.deepEqual([{
                source: '/Users/tangbin/fonts/aui.eot',
                format: 'embedded-opentype'
            }], WebFont.parseFontFaceSrc("url('../fonts/aui.eot?#iefix&v=4.5.0') format('embedded-opentype')", "/Users/tangbin/css/style.css"));
        });
        it("#5", function() {
            assert.deepEqual([{
                source: '/Users/tangbin/fonts/aui.ttf',
                format: 'truetype'
            }], WebFont.parseFontFaceSrc("url('../fonts/aui.ttf?v=4.5.0')", "/Users/tangbin/css/style.css"));
        });
    });

});
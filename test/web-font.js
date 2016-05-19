'use strict';

var WebFont = require('../src/spider/web-font.js');
var assert = require('assert');

describe('WebFont', function() {

    describe('#File', function() {
        it('toString()', function() {
            assert.deepEqual('/Document/font/test.ttf', (new WebFont.File(
                '/Document/css/style.css',
                '../font/test.ttf'
            )).toString());
        });
        it('format: truetype', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'truetype'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.ttf'
            ));
        });
        it('format: woff2', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff2',
                format: 'woff2'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.woff2'
            ));
        });
        it('format: woff', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff',
                format: 'woff'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.woff'
            ));
        });
        it('format: embedded-opentype', function() {
            assert.deepEqual({
                url: '/Document/font/test.eot',
                format: 'embedded-opentype'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.eot'
            ));
        });
        it('format: svg', function() {
            assert.deepEqual({
                url: '/Document/font/test.svg',
                format: 'svg'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.svg'
            ));
        });
        it('set format: truetype', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'truetype'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.ttf',
                'truetype'
            ));
        });
        it('set format: woff', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'woff'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.ttf',
                'woff'
            ));
        });
        it('local file', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff2',
                format: 'woff2'
            }, new WebFont.File(
                '/Document/css/style.css',
                '../font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('local file2', function() {
            assert.deepEqual({
                url: '/font/test.woff2',
                format: 'woff2'
            }, new WebFont.File(
                '/Document/css/style.css',
                '/font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.File(
                'http://font-spider.org/css/style.css',
                '../font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file2', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.File(
                'http://font-spider.org/css/style.css',
                '/font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file3', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new WebFont.File(
                '/Document/css/style.css',
                'http://font-spider.org/font/test.woff2?v=3#sfdsfs'
            ));
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
'use strict';

var parsers = require('../src/spider/parsers-utils.js');
var assert = require('assert');

var split = parsers.split;

describe('parsers', function() {
    describe('#split', function() {
        it('.class', function() {
            assert.deepEqual(['.class'], split('.class'));
        });
        it('.class, .class2, .class3 .class4', function() {
            assert.deepEqual(['.class', '.class2', '.class3 .class4'], split('.class, .class2, .class3 .class4'));
        });
        it('.class, [attr]', function() {
            assert.deepEqual(['.class', '[attr]'], split('.class, [attr]'));
        });
        it('.class, [attr=","]', function() {
            assert.deepEqual(['.class', '[attr=","]'], split('.class, [attr=","]'));
        });
        it(".class, [attr=',']", function() {
            assert.deepEqual(['.class', '[attr=\',\']'], split(".class, [attr=',']"));
        });
        it('.class, [attr=",\'"], .class2', function() {
            assert.deepEqual(['.class', '[attr=",\'"]', '.class2'], split('.class, [attr=",\'"], .class2'));
        });
        it('[attr="\\,"]', function() {
            assert.deepEqual(['[attr="\\,"]'], split('[attr="\\,"]'));
        });
        it('[attr="\\,\\"\'"]', function() {
            assert.deepEqual(['[attr="\\,\\"\'"]'], split('[attr="\\,\\"\'"]'));
        });
        it('.class, [attr="\\""], .class2', function() {
            assert.deepEqual(['.class', '[attr="\\""]', '.class2'], split('.class, [attr="\\""], .class2'));
        });
        it('\\n .class \\n,\\n   .class2', function() {
            assert.deepEqual(['.class', '.class2'], split('\n .class \n,\n   .class2'));
        });
        it('\\n .class \\n  ,  [attr^="   "],  \\n   .class2', function() {
            assert.deepEqual(['.class', '[attr^="   "]', '.class2'], split('\n .class \n  ,  [attr^="   "],  \n   .class2'));
        });
        it('[data-name="a,\\""], .class2', function() {
            assert.deepEqual(['[data-name="a,\\""]', '.class2'], split('[data-name="a,\\""], .class2'));
        });
        it('","', function() {
            assert.deepEqual(['","'], split('","'));
        });
        it('",", ",\\""', function() {
            assert.deepEqual(['","', '",\\""'], split('",", ",\\""'));
        });
        it('Arial,Helvetica,"Microsoft Yahei","\\","', function() {
            assert.deepEqual(['Arial', 'Helvetica', '"Microsoft Yahei"', '"\\","'], split('Arial,Helvetica,"Microsoft Yahei","\\","'));
        });
        it('', function() {
            assert.deepEqual([''], split('  '));
        });
        it('abc"def\'', function() {
            assert.deepEqual(['abc"def\''], split('abc"def\''));
        });
        it('"abc\\\\", "', function() {
            assert.deepEqual(['"abc\\\\"', '"'], split('"abc\\\\", "'));
        });

    });


    describe('#cssFontfamilyParser', function() {
        it('Arial', function() {
            assert.deepEqual(['Arial'], parsers.cssFontfamilyParser('Arial'));
        });
        it('Arial, "Helvetica"', function() {
            assert.deepEqual(['Arial', 'Helvetica'], parsers.cssFontfamilyParser('Arial, "Helvetica"'));
        });
        it('Arial, "Helvetica",  \'Microsoft Yahei\'', function() {
            assert.deepEqual(['Arial', 'Helvetica', 'Microsoft Yahei'], parsers.cssFontfamilyParser('Arial, "Helvetica",  \'Microsoft Yahei\''));
        });
        it('Arial, "Helvetica mini"', function() {
            assert.deepEqual(['Arial', 'Helvetica mini'], parsers.cssFontfamilyParser('Arial, "Helvetica mini"'));
        });
        it('Arial, "Helvetica, mini"', function() {
            assert.deepEqual(['Arial', 'Helvetica, mini'], parsers.cssFontfamilyParser('Arial, "Helvetica, mini"'));
        });
        it('Arial, ",\\"Helvetica, mini,\\"', function() {
            assert.deepEqual(['Arial', ',\\"Helvetica, mini,\\"'], parsers.cssFontfamilyParser('Arial, ",\\"Helvetica, mini,\\""'));
        });
    });


    describe('#cssFontFaceSrcParser.FontFile', function() {
        var FontFile = parsers.cssFontFaceSrcParser.FontFile;
        it('toString()', function() {
            assert.deepEqual('/Document/font/test.ttf', (new FontFile(
                '/Document/css/style.css',
                '../font/test.ttf'
            )).toString());
        });
        it('format: truetype', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'truetype'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.ttf'
            ));
        });
        it('format: woff2', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff2',
                format: 'woff2'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.woff2'
            ));
        });
        it('format: woff', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff',
                format: 'woff'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.woff'
            ));
        });
        it('format: embedded-opentype', function() {
            assert.deepEqual({
                url: '/Document/font/test.eot',
                format: 'embedded-opentype'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.eot'
            ));
        });
        it('format: svg', function() {
            assert.deepEqual({
                url: '/Document/font/test.svg',
                format: 'svg'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.svg'
            ));
        });
        it('set format: truetype', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'truetype'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.ttf',
                'truetype'
            ));
        });
        it('set format: woff', function() {
            assert.deepEqual({
                url: '/Document/font/test.ttf',
                format: 'woff'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.ttf',
                'woff'
            ));
        });
        it('local file', function() {
            assert.deepEqual({
                url: '/Document/font/test.woff2',
                format: 'woff2'
            }, new FontFile(
                '/Document/css/style.css',
                '../font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('local file2', function() {
            assert.deepEqual({
                url: '/font/test.woff2',
                format: 'woff2'
            }, new FontFile(
                '/Document/css/style.css',
                '/font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new FontFile(
                'http://font-spider.org/css/style.css',
                '../font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file2', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new FontFile(
                'http://font-spider.org/css/style.css',
                '/font/test.woff2?v=3#sfdsfs'
            ));
        });
        it('remote file3', function() {
            assert.deepEqual({
                url: 'http://font-spider.org/font/test.woff2?v=3',
                format: 'woff2'
            }, new FontFile(
                '/Document/css/style.css',
                'http://font-spider.org/font/test.woff2?v=3#sfdsfs'
            ));
        });
    });

    describe('#cssFontFaceSrcParser', function() {
        it("#1", function() {
            assert.deepEqual([{
                url: 'http://font.org/fonts/aui.woff2?v=4.5.0',
                format: 'woff2'
            }], parsers.cssFontFaceSrcParser("url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "http://font.org/css/style.css"));
        });
        it('#2', function() {
            assert.deepEqual([{
                url: 'http://font.org/fonts/aui.eot?',
                format: 'embedded-opentype'
            }, {
                url: 'http://font.org/fonts/aui.woff2?v=4.5.0',
                format: 'woff2'
            }], parsers.cssFontFaceSrcParser("url('../fonts/aui.eot?#iefix&v=4.5.0') format('embedded-opentype'), url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "http://font.org/css/style.css"));
        });
        it("#3", function() {
            assert.deepEqual([{
                url: '/Users/tangbin/fonts/aui.woff2',
                format: 'woff2'
            }], parsers.cssFontFaceSrcParser("url('../fonts/aui.woff2?v=4.5.0') format('woff2')", "/Users/tangbin/css/style.css"));
        });
        it("#4", function() {
            assert.deepEqual([{
                url: '/Users/tangbin/fonts/aui.eot',
                format: 'embedded-opentype'
            }], parsers.cssFontFaceSrcParser("url('../fonts/aui.eot?#iefix&v=4.5.0') format('embedded-opentype')", "/Users/tangbin/css/style.css"));
        });
        it("#5", function() {
            assert.deepEqual([{
                url: '/Users/tangbin/fonts/aui.ttf',
                format: 'truetype'
            }], parsers.cssFontFaceSrcParser("url('../fonts/aui.ttf?v=4.5.0')", "/Users/tangbin/css/style.css"));
        });
    });

    describe('#cssContentParser', function() {
        it('"hello world"', function() {
            assert.deepEqual([{
                type: 'string',
                value: "hello world"
            }], parsers.cssContentParser('"hello world"'));
        });
        it("'hello world'", function() {
            assert.deepEqual([{
                type: 'string',
                value: "hello world"
            }], parsers.cssContentParser("'hello world'"));
        });
        it("\"hello \\\" world\"", function() {
            assert.deepEqual([{
                type: 'string',
                value: "hello \" world"
            }], parsers.cssContentParser("\"hello \\\" world\""));
        });
        it("\"hello \\\\' world\"", function() {
            assert.deepEqual([{
                type: 'string',
                value: "hello \\' world"
            }], parsers.cssContentParser("\"hello \\\\' world\""));
        });
        it("\"hello \\\\\\\" world\"", function() {
            assert.deepEqual([{
                type: 'string',
                value: "hello \\\" world"
            }], parsers.cssContentParser("\"hello \\\\\\\" world\""));
        });
        it('"hello" attr(data-name) "world"', function() {
            assert.deepEqual([{
                type: 'string',
                value: "hello"
            }, {
                type: 'attr',
                value: "data-name"
            }, {
                type: 'string',
                value: "world"
            }], parsers.cssContentParser('"hello" attr(data-name) "world"'));
        });
        it('"hello" attr($data) "world"', function() {
            var value;
            try{
                value = parsers.cssContentParser('"hello" attr($data) "world"');
            } catch(e) {
                return;
            }
            throw new Error('Parser: ' + JSON.stringify(value));
        });
    });
});
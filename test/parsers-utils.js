'use strict';

var parsers = require('../src/spider/parsers-utils.js');
var assert = require('assert');

var split = parsers.split;

describe('parsers-utils', function() {
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
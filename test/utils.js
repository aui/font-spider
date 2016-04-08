'use strict';

var utils = require('../src/spider/utils.js');
var assert = require('assert');

var split = utils.split;

describe('Utils', function() {
    describe('#split', function() {
        it('.class', function() {
            assert.deepEqual(['.class'], split('.class'));
        });
        it('.class, .class2', function() {
            assert.deepEqual(['.class', '.class2'], split('.class, .class2'));
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
        it('\n .class \n,\n   .class2', function() {
            assert.deepEqual(['.class', '.class2'], split('\n .class \n,\n   .class2'));
        });
        it('\n .class \n  ,  [attr^="   "],  \n   .class2', function() {
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
    });
});
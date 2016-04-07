'use strict';

var utils = require('../src/spider/utils.js');
var assert = require('assert');

var split = utils.split;

describe('Utils', function() {
    describe('#split', function() {
        it("#1", function() {
            assert.deepEqual(['.class'], split('.class'));
        });
        it("#2", function() {
            assert.deepEqual(['.class', '.class2'], split('.class, .class2'));
        });
        it("#3", function() {
            assert.deepEqual(['.class', '[attr]'], split('.class, [attr]'));
        });
        it("#4", function() {
            assert.deepEqual(['.class', '[attr=","]'], split('.class, [attr=","]'));
        });
        it("#5", function() {
            assert.deepEqual(['.class', '[attr=\',\']'], split(".class, [attr=',']"));
        });
        it("#6", function() {
            assert.deepEqual(['.class', '[attr=",\'"]', '.class2'], split('.class, [attr=",\'"], .class2'));
        });
        it("#7", function() {
            assert.deepEqual(['[attr="\\,"]'], split('[attr="\\,"]'));
        });
        it("#8", function() {
            assert.deepEqual(['[attr="\\,\\"\'"]'], split('[attr="\\,\\"\'"]'));
        });
        it("#9", function() {
            assert.deepEqual(['.class', '[attr="\\""]', '.class2'], split('.class, [attr="\\""], .class2'));
        });
        it("#10", function() {
            assert.deepEqual(['.class', '.class2'], split('\n .class \n,\n   .class2'));
        });
        it("#11", function() {
            assert.deepEqual(['.class', '[attr^="   "]', '.class2'], split('\n .class \n  ,  [attr^="   "],  \n   .class2'));
        });
    });
});
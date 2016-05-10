'use strict';

var Adapter = require('../src/adapter.js');
var assert = require('assert');

describe('Adapter', function() {

    describe('#map', function() {
        var adapter = new Adapter({
            map: [
                ['http://font-spider.org/font', '/Document/font'],
                [/\?v=(\d)+$/, '?xxx=$1'],
                ['name=(.*?)\\.bk$', 'name2=$1'],
                ['aaa', 'bbb']
            ]
        });
        it('map string', function() {
            assert.equal('/Document/font/test.woff', adapter.resourceMap('http://font-spider.org/font/test.woff'));
        });
        it('map regexp', function() {
            assert.equal('/Document/font/test.woff?xxx=1', adapter.resourceMap('http://font-spider.org/font/test.woff?v=1'));
        });
        it('map regexp: string', function() {
            assert.equal('/Document/font/test.woff?v=1&name2=ddd', adapter.resourceMap('http://font-spider.org/font/test.woff?v=1&name=ddd.bk'));
        });
        it('map regexp: g', function() {
            assert.equal('/Document/font/bbb-bbb-bbb.woff', adapter.resourceMap('http://font-spider.org/font/aaa-aaa-bbb.woff'));
        });
    });

    describe('#ignore', function() {
        it('basic', function() {
            var adapter = new Adapter({
                ignore: ['xxx.ttf$', '.*?.otf$', 'xxx/bk/.*?.woff$']
            });
            assert.equal(false, adapter.resourceIgnore('http://font-spider.org/font/test.woff'));
            assert.equal(true, adapter.resourceIgnore('http://font-spider.org/font/xxx.ttf'));
            assert.equal(true, adapter.resourceIgnore('ssssss.otf'));
            assert.equal(true, adapter.resourceIgnore('xxx/bk/bbb.woff'));
            assert.equal(false, adapter.resourceIgnore('xxx/bk/bbb.ttf'));
        });
        // it('windows path', function() {
        //     var adapter = new Adapter({
        //         ignore: ['file/font/test.ttf$']
        //     });
        //     assert.equal(true, adapter.resourceIgnore('/Document/aui/file/font/test.ttf'));
        //     assert.equal(true, adapter.resourceIgnore('\\Document\\aui\\file\\font\\test.ttf'));
        // });
    });

});
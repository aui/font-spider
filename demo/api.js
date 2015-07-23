/* global require,console,process,__dirname */

'use strict';

var fs = require('fs');
var path = require('path');
var FontSpider = require('../');// require('font-spider');

new FontSpider.Spider([
        'http://font-spider.org/index.html',
        'http://font-spider.org/install.html'
    ], {
    
    // CSS @import 语法导入的文件数量限制
    maxImportFiles: 16,
    
    // 忽略的文件规则。语法 @see https://github.com/kaelzhang/node-ignore
    ignore: ['*.eot', 'icons.css', 'font?name=*'],
    
    // 路径映射规则。映射远程路径到本地（远程字体文件必须映射到本地才能压缩）
    map: [
        ['http://font-spider.org/font', __dirname + '/../release/font'],
        ['http://font-spider.org/css', __dirname + '/../release/css']
    ],

    // 资源加载前事件
    resourceBeforeLoad: function (file) {
        var RE_SERVER = /^https?\:\/\//i
        var REG_DOMAIN = /^https?\:\/\/(?:\w+\.)?font-spider\.org/;

        if (RE_SERVER.test(file)) {
            if (!REG_DOMAIN.test(file)) {
                throw new Error('只允许来自 font-spider.org 网站的资源请求');
            }
        } else {
            var base = path.resolve(__dirname + '/../release');
            if (file.indexOf(base) !== 0) {
                throw new Error('资源访问超出目录限制');
            }
        }


    },

    // 资源加载成功事件
    resourceLoad: function (file) {
        console.log('Load', file);
    },

    // 资源加载失败事件
    resourceError: function (file) {},

    // 爬虫爬行页面前事件
    spiderBeforeLoad: function (htmlFile) {},

    // 爬虫解析页面完成事件
    spiderLoad: function (htmlFile) {},

    // 爬虫解析错误事件
    spiderError: function (htmlFile) {}
})
.then(function (data) {
    return Promise
    .all(data.map(function (item) {
        return new FontSpider.Compress(item, {
            // 是否备份原始字体
            backup: true
        });
    }));
})
.then(function (data) {
    if (data.length === 0) {
        console.log('web font not found');
        return;
    }

    data.forEach(function (item) {
        console.log('Font name:', item.name);
        console.log('Font id:', item.id);
        console.log('Original size:', item.originalSize / 1000, 'KB');
        console.log('Include chars:', item.chars);

        item.files.forEach(function (file) {
            if (fs.existsSync(file)) {
                console.log('File', path.relative('./', file),
                    'created:', fs.statSync(file).size / 1000, 'KB');
            } else {
                console.error('File', path.relative('./', file), 'not created');
            }
        });
    });
})
.catch(function (errors) {
    console.log('Error:', errors.stack.toString());
    process.exit(1);
});


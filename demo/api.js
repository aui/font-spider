/* global require,console,process,__dirname */

'use strict';

var fs = require('fs');
var path = require('path');
var FontSpider = require('../');// require('font-spider');

new FontSpider

// 分析 WebFont
.Spider([
        'http://font-spider.org/index.html',
        'http://font-spider.org/install.html'
    ], {
    
    // 忽略的文件规则。语法 @see https://github.com/kaelzhang/node-ignore
    ignore: ['*.eot', 'icons.css', 'font?name=*'],
    
    // 路径映射规则。映射远程路径到本地（远程字体文件必须映射到本地才能压缩）
    map: [
        ['http://font-spider.org/font', __dirname + '/../release/font'],
        ['http://font-spider.org/css', __dirname + '/../release/css']
    ],

    // CSS @import 语法导入的文件数量限制，避免爬虫陷入死循环陷阱
    maxImportCss: 16,

    // 资源加载前事件
    resourceBeforeLoad: function (file) {},

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

// 压缩字体
.then(function (webFonts) {
    return Promise
    .all(webFonts.map(function (webFont) {
        return new FontSpider.Compress(webFont, {
            // 是否备份原始字体
            backup: true
        });
    }));
})

// 显示压缩结果
.then(function (webFonts) {
    if (webFonts.length === 0) {
        console.log('web font not found');
        return;
    }

    webFonts.forEach(function (webFont) {
        console.log('Font name:', webFont.name);
        console.log('Font id:', webFont.id);
        console.log('Original size:', webFont.originalSize / 1000, 'KB');
        console.log('Include chars:', webFont.chars);

        webFont.files.forEach(function (file) {
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


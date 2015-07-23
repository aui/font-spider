# font-spider

font-spider 的接口基于 `Promise` 。

## 安装

``` shell
npm install font-spider --save
```

## API

这样调用 font-spider：

``` javascript
var FontSpider = require('font-spider');
```

font-spider 有两个主要方法：

- `Spider` 爬虫模块
- `Compress` 压缩模块

### new FontSpider.Spider(htmlFiles, options)

爬虫模块

#### 参数

- `htmlFiles` 本地或远程 HTML 文件列表
- `options` 爬虫选项

#### 返回

`Promise` 接收 webFont 描述信息

#### 选项

- `ignore` 忽略列表，用来忽略路径或文件。[语法示例](https://github.com/kaelzhang/node-ignore)
- `map` 映射规则，支持映射远程路径到本地（远程字体需要映射到本地才能压缩）
- `maxImportCss` CSS `@import` 语法导入的文件数量限制，避免爬虫陷入死循环陷阱
- `resourceBeforeLoad` 资源准备加载的事件
- `resourceLoad` 资源加载成功的事件
- `resourceError` 资源加载失败的事件
- `spiderBeforeLoad` 爬虫准备爬页面的事件
- `spiderLoad` 爬虫解析成功后的事件
- `spiderError` 爬虫解析失败后的事件

> 注意：事件后续考虑使用 `on(type, callback)` 方法来支持

#### 示例

``` javascript
var FontSpider = require('font-spider');
new FontSpider.Spider([
        'http://font-spider.org/index.html'
    ], {
    ignore: ['*.eot', 'icons.css', 'font?name=*'],
    map: [
        ['http://font-spider.org/css', __dirname + '/../release/css']
    ],
    resourceLoad: function (file) {
        console.log('Load', file);
    }
})
.then(function (webFonts) {
    return Promise
    .all(webFonts.map(function (webFont) {
        console.log('Font name:', webFont.name);
        console.log('Font id:', webFont.id);
        console.log('Include chars:', webFont.chars);
        console.log('Font files:', webFont.files)
    }));
})
.catch(function (errors) {
    console.log('Error:', errors.stack.toString());
    process.exit(1);
});
```

### new FontSpider.Compress(webFont, options)

压缩与转码模块

#### 参数

- `webFont` webFont 描述信息（可以通过 `FontSpider.Spider` 获取到）
- `options` 压缩器选项

#### 返回

webFont 描述信息

#### 选项

- `backup` 是否开启备份功能

#### 示例

``` javascript
var FontSpider = require('font-spider');
new FontSpider.Spider([
    'http://font-spider.org/index.html',
]).then(function (webFonts) {
    return Promise
    .all(webFonts.map(function (item) {
        return new FontSpider.Compress(item, {
            backup: true
        });
    }));
});
```

## 完整示例

使用 font-spider 构造一个 CDN 字体动态压缩服务的示例：

``` javascript
'use strict';

var fs = require('fs');
var path = require('path');
var FontSpider = require('font-spider');

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
    resourceBeforeLoad: function (file) {
        var RE_SERVER = /^https?\:\/\//i;
        var REG_DOMAIN = /^https?\:\/\/(?:\w+\.)?font-spider\.org/;

        if (RE_SERVER.test(file)) {
            if (!REG_DOMAIN.test(file)) {
                throw new Error('只允许来自 font-spider.org 网站的资源请求');
            }
        } else {
            var base = path.resolve(__dirname + '/../release');
            if (file.indexOf(base) !== 0) {
                throw new Error('禁止访问上层目录');
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
```


# font-spider

font-spider 由爬虫模块与压缩模块组成，其接口基于 `Promise` 实现。

## API

``` javascript
var FontSpider = require('font-spider');
```

### new FontSpider.Spider(htmlFiles, options)

爬虫模块

#### 参数

- `htmlFiles` 本地或远程 HTML 文件列表
- `options` 爬虫选项

#### 返回

`Promise` 接收 webFont 描述信息列表

#### 示例

``` javascript
var FontSpider = require('font-spider');
new FontSpider.Spider([__dirname + '/index.html'])
.then(function (webFonts) {
    console.log(webFonts);
})
.catch(function (errors) {
    console.error('Error:', errors.stack.toString());
});
```

#### 选项

- `ignore` 忽略列表，用来忽略路径或文件。[语法示例](https://github.com/kaelzhang/node-ignore)
  - 类型：`Array` `Function`
  - 示例：`['icon.css', '*.eot']`
- `map` 映射规则（支持正则），用来映射远程路径到本地（远程字体需要映射到本地才能压缩）
  - 类型：`Array` `Function`
  - 示例：`[['http://font-spider.org/css', __dirname + '/css'], [...]]`
- `maxImportCss` CSS `@import` 语法导入的文件数量限制，避免爬虫陷入死循环陷阱（默认值 `16`）
- `resourceBeforeLoad` 事件：资源准备加载
- `resourceLoad` 事件：资源加载成功
- `resourceError` 事件：资源加载失败
- `spiderBeforeLoad` 事件：爬虫准备解析
- `spiderLoad` 事件：爬虫解析成功
- `spiderError` 事件：爬虫解析失败

> 事件第一个参数可以获取文件路径

### new FontSpider.Compress(webFont, options)

压缩与转码模块

#### 参数

- `webFont` webFont 描述信息（可以通过 `FontSpider.Spider` 获取到）
- `options` 压缩器选项

#### 返回

webFont 描述信息

#### 示例

``` javascript
var FontSpider = require('font-spider');
new FontSpider.Spider([__dirname + '/index.html'])
.then(function (webFonts) {
    webFonts.forEach(function (item) {
        new FontSpider.Compress(item, {
            backup: true
        });
    });
})
.catch(function (errors) {
    console.error('Error:', errors.stack.toString());
});
```

#### 选项

- `backup` 是否开启备份功能（开启备份功能后支持反复压缩字体）

## 完整示例

使用 font-spider 构造一个 CDN 字体动态压缩服务的示例（脚本与字体文件在同一台服务器）：

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
    // 也可以自定义 map 函数，来限制目录的访问
    map: [
    	['http://font-spider.org/font', __dirname + '/../release/font']
    ],

    // 资源加载成功事件
    resourceLoad: function (file) {
        console.log('Load', file);
    }
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
    console.error('Error:', errors.stack.toString());
});
```

> 本文档针对 font-spider v0.3+ 撰写
# 字蛛

中文 WebFont 自动化压缩工具，它能自动分析页面使用的 WebFont 并进行按需压缩。

官方网站：<http://font-spider.org>

## 特性

相对于图片，WebFont 拥有更好的体验。它支持选中、搜索、翻译、朗读、缩放等，而字蛛作为一个 WebFont 压缩转码工具，拥有如下特性：

1. 按需压缩：数 MB 的中文字体可被压成几十 KB
2. 简单可靠：完全基于 CSS 规则，无需 js 与服务端辅助
3. 自动转码：支持 IE 与标准化的浏览器

## 安装

安装好 [nodejs](http://nodejs.org)，然后执行：

``` 
npm install font-spider -g
```

## 使用范例

### 一、书写 CSS

``` css
/*声明 WebFont*/
@font-face {
  font-family: 'pinghei';
  src: url('../font/pinghei.eot');
  src:
    url('../font/pinghei.eot?#font-spider') format('embedded-opentype'),
    url('../font/pinghei.woff') format('woff'),
    url('../font/pinghei.ttf') format('truetype'),
    url('../font/pinghei.svg') format('svg');
  font-weight: normal;
  font-style: normal;
}

/*使用选择器指定字体*/
.home h1, .demo > .test {
    font-family: 'pinghei';
}
```

> 特别说明： `@font-face` 中的 `src` 定义的 .ttf 文件必须存在，其余的格式将由工具自动生成

### 二、压缩 WebFont

``` 
font-spider [options] <htmlFile ...>
```

> 支持通配符，例如：`font-spider dest/*.html`

#### options

``` 
-h, --help                    输出帮助信息
-V, --version                 输出当前版本号
--info                        仅提取 WebFont 信息显示，不压缩与转码
--ignore <pattern>            忽略的文件配置（可以是字体、CSS、HTML）
--map <remotePath,localPath>  映射 CSS 内部 HTTP 路径到本地
--no-backup                   关闭字体备份功能
```

## 前端构建工具集成

- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

## API

``` javascript
var fs = require('fs');
var path = require('path');
var FontSpider = require('font-spider');


new FontSpider.Spider([
        'http://font-spider.org/index.html',
        'http://font-spider.org/install.html'
    ], {
    
    // CSS @import 语法导入的文件数量限制
    maxImportFiles: 16,
    
    // 忽略的文件规则。语法 @see https://github.com/kaelzhang/node-ignore
    ignore: ['*.eot', 'icons.css', 'font?name=*'],
    
    // 路径映射规则。映射远程路径到本地（远程字体文件必须映射到本地才能处理）
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
```

## 使用场景限制

- 不支持元素行内样式（仅支持 `<link>` 与 `<style>` 标签声明的样式）
- CSS `content` 属性插入的字符需要定义 `font-family`，不支持继承
- 不支持 javascript 动态插入的样式与元素节点
- 不支持 .otf 格式的字体

## 字体兼容性参考

| 格式      | IE   | Firefox | Chrome | Safari | Opera | iOS Safari | Android Browser | Chrome for Android | 
| ------- | ---- | ------- | ------ | ------ | ----- | ---------- | --------------- | ------------------ | 
| `.eot`  | 6    | --      | --     | --     | --    | --         | --              | --                 | 
| `.woff` | 9    | 3.6     | 5      | 5.1    | 11.1  | 5.1        | 4.4             | 36                 | 
| `.ttf`  | --   | 3.5     | 4      | 3.1    | 10.1  | 4.3        | 2.2             | 36                 | 
| `.svg`  | --   | --      | 4      | 3.2    | 9.6   | 3.2        | 3               | 36                 | 

来源：<http://caniuse.com/#feat=fontface>

## 更新日志

### 0.3.0

- 重构爬虫模块，解决压缩后的 CSS 解析失败的问题
- 同名字体支持 [#32](https://github.com/aui/font-spider/issues/32)
- 改进错误流程处理：HTML、CSS 加载与解析错误都会进入错误流程

[更多](./CHANGELOG.md)

## 贡献者

- [@糖饼](https://github.com/aui) [微博](http://www.weibo.com/planeart)
- @fufu [微博](http://www.weibo.com/u/1715968673)
- @kdd [微博](http://www.weibo.com/kddie)

### 特别鸣谢

字蛛自 v0.2 版本开始，使用了百度前端团队开源作品 —— [fontmin](https://github.com/ecomfe/fontmin) 取代了字蛛内置的字体压缩库。

字蛛希望与更多的人或团队一起合作，推动中文 WebFont 发展。

=============

*字体受版权保护，若在网页中使用商业字体，请联系相关字体厂商购买授权*

[![NPM](https://nodei.co/npm/font-spider.png?downloads=true&stars=true)](https://nodei.co/npm/font-spider/)
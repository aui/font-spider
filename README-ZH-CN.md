# 字蛛（font-spider）

[![NPM Version][npm-image]][npm-url]
[![NPM Downloads][downloads-image]][downloads-url]
[![Node.js Version][node-version-image]][node-version-url]
[![Build Status][travis-ci-image]][travis-ci-url]

[[简体中文]](./README-ZH-CN.md) | [[English]](./README.md) | [[日本語]](./README-JA.md)

字蛛是一个智能 WebFont 压缩工具，它能自动分析出页面使用的 WebFont 并进行按需压缩。

网站：<http://font-spider.org>

<img alt="font-spider 命令行界面" width="670" src="https://cloud.githubusercontent.com/assets/1791748/15415184/8bc574ac-1e73-11e6-92b9-515281620e9d.png">

## 特性

1. 压缩字体：智能删除没有被使用的字形数据，大幅度减少字体体积
2. 生成字体：支持 woff2、woff、eot、svg 字体格式生成

> New: 字蛛 v1.0.0 版本支持图标字体！[更新日志](./CHANGELOG.md)

## 安装

安装好 [nodejs](http://nodejs.org)，然后执行：

``` shell
npm install font-spider -g
```

## 使用范例

### 一、书写 CSS

``` css
/*声明 WebFont*/
@font-face {
  font-family: 'source';
  src: url('../font/source.eot');
  src:
    url('../font/source.eot?#font-spider') format('embedded-opentype'),
    url('../font/source.woff2') format('woff2'),
    url('../font/source.woff') format('woff'),
    url('../font/source.ttf') format('truetype'),
    url('../font/source.svg') format('svg');
  font-weight: normal;
  font-style: normal;
}

/*使用指定字体*/
.home h1, .demo > .test {
    font-family: 'source';
}
```

> 特别说明： `@font-face` 中的 `src` 定义的 .ttf 文件必须存在，其余的格式将由工具自动生成

### 二、压缩 WebFont

``` shell
font-spider [options] <htmlFile1 htmlFile2 ...>
```

#### htmlFiles

一个或多个页面地址，支持 http 形式。

例如：

``` shell
font-spider dest/news.html dest/index.html dest/about.html
```

> 如果有多个页面依赖相同的字体，请都传递进来

#### options

```
-h, --help                    输出帮助信息
-V, --version                 输出当前版本号
--info                        输出 WebFont 的 JSON 描述信息，不压缩与转码
--ignore <pattern>            忽略的文件配置（支持正则表达式）
--map <remotePath,localPath>  映射 CSS 内部 HTTP 路径到本地（支持正则表达式）
--no-backup                   关闭字体备份功能
--debug                       调试模式，打开它可以显示 CSS 解析错误
```

#### 参数使用示例

使用通配符压缩多个 HTML 文件关联的 WebFont：

``` shell
font-spider dest/*.html
```

`--info` 查看网站所应用的 WebFont：

``` shell
font-spider --info http://fontawesome.io
```

`--ignore` 忽略文件：

``` shell
font-spider --ignore "icon\\.css$" dest/*.html
```

`--map` 参数将线上的页面的 WebFont 映射到本地来进行压缩（本地路径必须使用绝对路径）：

``` shell
font-spider --map "http://font-spider.org/font,/Website/font" http://font-spider.org/index.html
```

## 构建插件

- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

## API

font-spider 包括爬虫与压缩器模块，接口文档：[API.md](./API.md)

## 限制

- 不支持 javascript 动态插入的元素与样式
- .otf 字体需要转换成 .ttf 格式才能被压缩（[免费 ttf 字体资源](#免费字体)）
- 仅支持 `utf-8` 编码的 HTML 与 CSS 文件
- CSS `content` 仅支持 `content: 'prefix'` 和 `content: attr(value)` 这两种形式

## 字体兼容性参考

| 格式      | IE   | Edge | Firefox | Chrome | Safari | Opera | iOS Safari | Android Browser | Chrome for Android |
| -------  | ---- | ---- | ------- | ------ | ------ | ----- | ---------- | --------------- | ------------------ |
| `.eot`   | 6    | \-\- | \-\-    | \-\-   | \-\-   | \-\-  | \-\-       | \-\-            | \-\-               |
| `.woff`  | 9    | 13   | 3.6     | 5      | 5.1    | 11.1  | 5.1        | 4.4             | 36                 |
| `.woff2` | \-\- | 14   | 39      | 36     | \-\-   | 23    | \-\-       | 50              | 50                 |
| `.ttf`   | \-\- | 13   | 3.5     | 4      | 3.1    | 10.1  | 4.3        | 2.2             | 36                 |
| `.svg`   | \-\- | \-\- | \-\-    | 4      | 3.2    | 9.6   | 3.2        | 3               | 36                 |

来源：<http://caniuse.com/#feat=fontface>

## 贡献者

- [@糖饼](https://github.com/aui) - 前端工程师，[厦门欢乐逛](http://www.huanleguang.com)，[微博](http://www.weibo.com/planeart)
- [@fufu](https://github.com/milansnow) - UI 工程师，[腾讯ISUX](http://isux.tencent.com)，[微博](http://www.weibo.com/u/1715968673)
- @kdd - 视觉设计师，[腾讯ISUX](http://isux.tencent.com)，[微博](http://www.weibo.com/kddie)
- [@crabkiller](https://github.com/crabkiller) - 文档贡献者，[厦门欢乐逛](http://www.huanleguang.com)
- [@dorawei](https://github.com/dorawei) - 文档贡献者

## 免费字体

- [思源黑体: 简体中文 ttf 版本](https://github.com/aui/free-fonts/archive/KaiGenGothic-1.001-SimplifiedChinese.zip)
- [思源黑体: 繁体中文 ttf 版本](https://github.com/aui/free-fonts/archive/KaiGenGothic-1.001-TraditionalChinese.zip)
- [思源黑体: 中、日、韩 ttf 版本](https://mega.nz/#!PZxFSYQI!ICvNugaFX_y4Mh003-S3fao1zU0uNpeSyprdmvHDnwc)
- [开源图标字体: Font Awesome](http://fontawesome.io)

## 相关链接

- [字蛛文档翻译计划：征集日文、韩文翻译志愿者](https://github.com/aui/font-spider/issues/71)
- [字蛛开发计划](https://github.com/aui/font-spider/issues/2)
- [字蛛更新日志](./CHANGELOG.md)
- [字蛛接口文档](./API.md)
- [字蛛 grunt 版本](https://github.com/aui/grunt-font-spider)
- [字蛛 gulp 版本](https://github.com/aui/gulp-font-spider)
- [Google: 网页字体优化](https://developers.google.com/web/fundamentals/performance/optimizing-content-efficiency/webfont-optimization?hl=zh-cn)
- [Baidu: fontmin](https://github.com/ecomfe/fontmin)

[npm-image]: https://img.shields.io/npm/v/font-spider.svg
[npm-url]: https://npmjs.org/package/font-spider
[node-version-image]: https://img.shields.io/node/v/font-spider.svg
[node-version-url]: http://nodejs.org/download/
[downloads-image]: https://img.shields.io/npm/dm/font-spider.svg
[downloads-url]: https://npmjs.org/package/font-spider
[travis-ci-image]: https://travis-ci.org/aui/font-spider.svg?branch=master
[travis-ci-url]: https://travis-ci.org/aui/font-spider

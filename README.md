# 字蛛

[![NPM Version][npm-image]][npm-url]
[![NPM Downloads][downloads-image]][downloads-url]
[![Node.js Version][node-version-image]][node-version-url]
[![Build Status][travis-ci-image]][travis-ci-url]

字蛛是一个中文 WebFont 自动化压缩工具，它能自动分析页面使用的 WebFont 并进行按需压缩，无需手工配置。

官方网站：<http://font-spider.org>

## 特性

1. 按需压缩：从原字体中剔除没有用到的字符，可以将数 MB 大小的中文字体压缩成几十 KB
2. 本地处理：完全基于 HTML 与 CSS 分析进行本地处理，无需 js 与服务端辅助
3. 自动转码：将字体转码成所有浏览器支持的格式，包括老旧的 IE6 与现代浏览器

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

``` shell
font-spider [options] <htmlFile ...>
```

例如：

``` shell
font-spider dest/news.html dest/index.html dest/about.html
```

#### options

``` shell
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
font-spider --ignore "-icon.css$, .eot$" dest/*.html
```

`--map` 参数将线上的页面的 WebFont 映射到本地来进行压缩（本地路径必须使用绝对路径）：

``` shell
font-spider --map "http://font-spider.org/font, /Website/font" http://font-spider.org/index.html
```

## 构建插件

- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

## API

font-spider 包括爬虫与压缩器模块，接口文档：[API.md](./API.md)

## 限制

- 仅支持固定的文本与样式，不支持 javascript 动态插入的元素与样式
- .otf 字体需要转换成 .ttf 格式才能被压缩（[免费 ttf 字体资源](#免费字体)）
- 仅支持 `utf-8` 编码的 HTML 与 CSS 文件
- CSS `content` 属性只支持普通文本，不支持属性、计数器等特性

## 字体兼容性参考

| 格式      | IE   | Firefox | Chrome | Safari | Opera | iOS Safari | Android Browser | Chrome for Android | 
| ------- | ---- | ------- | ------ | ------ | ----- | ---------- | --------------- | ------------------ | 
| `.eot`  | 6    | --      | --     | --     | --    | --         | --              | --                 | 
| `.woff` | 9    | 3.6     | 5      | 5.1    | 11.1  | 5.1        | 4.4             | 36                 | 
| `.ttf`  | --   | 3.5     | 4      | 3.1    | 10.1  | 4.3        | 2.2             | 36                 | 
| `.svg`  | --   | --      | 4      | 3.2    | 9.6   | 3.2        | 3               | 36                 | 

来源：<http://caniuse.com/#feat=fontface>

## 贡献者

- [@糖饼](https://github.com/aui) - [微博](http://www.weibo.com/planeart)
- @fufu  - [微博](http://www.weibo.com/u/1715968673)
- @kdd - [微博](http://www.weibo.com/kddie)

## 免费字体

- [思源黑体: 简体中文 ttf 版本](https://github.com/aui/free-fonts/archive/1.001-SimplifiedChinese.zip)
- [思源黑体: 繁体中文 ttf 版本](https://github.com/aui/free-fonts/archive/1.001-TraditionalChinese.zip)
- [思源黑体: 中、日、韩 ttf 版本](https://mega.nz/#!PZxFSYQI!ICvNugaFX_y4Mh003-S3fao1zU0uNpeSyprdmvHDnwc)
- [开源图标字体: fontawesome](http://fontawesome.io)

## 相关链接

- [字蛛开发计划](https://github.com/aui/font-spider/issues/2)
- [字蛛更新日志](./CHANGELOG.md)
- [字蛛接口文档](./API.md)
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
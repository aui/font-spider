# 字蛛

[![NPM Version][npm-image]][npm-url]
[![NPM Downloads][downloads-image]][downloads-url]
[![Node.js Version][node-version-image]][node-version-url]
[![Build Status][travis-image]][travis-url]
[![Test Coverage][coveralls-image]][coveralls-url]

中文 WebFont 自动化压缩工具，它能自动分析页面使用的 WebFont 并进行按需压缩。

官方网站：<http://font-spider.org>

## 特性

相对于图片，WebFont 拥有更好的体验。它支持选中、搜索、翻译、朗读、缩放等，而字蛛作为一个 WebFont 压缩转码工具，拥有如下特性：

1. 按需压缩：数 MB 的中文字体可被压成几十 KB
2. 简单可靠：完全基于 CSS 规则，无需 js 与服务端辅助
3. 自动转码：支持 IE 与标准化的浏览器

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

> 支持通配符，例如：`font-spider dest/*.html`

#### options

``` shell
-h, --help                    输出帮助信息
-V, --version                 输出当前版本号
--info                        仅提取 WebFont 信息显示，不压缩与转码
--ignore <pattern>            忽略的文件配置（可以是字体、CSS、HTML）
--map <remotePath,localPath>  映射 CSS 内部 HTTP 路径到本地
--no-backup                   关闭字体备份功能
```

## 构建插件

- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

## API

使用 font-spider 的 API，可以构建在线动态字体压缩服务。

文档参见：[DOCS.md](./DOCS.md)

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

### v0.3.2

- 重构爬虫模块，解决压缩后的 CSS 解析失败的问题
- `font` 属性缩写支持、多个`@font-face`同名字体支持 [#32](https://github.com/aui/font-spider/issues/32)
- 改进错误流程处理：HTML、CSS 加载与解析错误都会进入错误流程
- 提供对外接口
- 支持 http 与 https 远程资源解析

[更多日志](./CHANGELOG.md)

## 贡献者

- [@糖饼](https://github.com/aui) - [微博](http://www.weibo.com/planeart)
- @fufu  - [微博](http://www.weibo.com/u/1715968673)
- @kdd - [微博](http://www.weibo.com/kddie)

### 鸣谢

字蛛的发展离不开以下开源项目的支持：

- [fontmin](https://github.com/ecomfe/fontmin) 来自百度前端团队的字体压缩库*（字蛛 v0.2 版本使用它取代了内置的字体压缩库 [#18](https://github.com/aui/font-spider/issues/18)）*
- [cssom](https://github.com/NV/CSSOM) 标准化的 CSS 解析库*（字蛛 v0.3 版本使用它取代了 [css](https://github.com/reworkcss/css)）*
- [cheerio](https://github.com/cheeriojs/cheerio) 轻量的 HTML 解析库*（字蛛 v0.2 版本使用它取代了 [jsdom](https://github.com/tmpvar/jsdom)）*

==========

字蛛愿以开放的心态和开源社区一起推动中文 WebFont 发展。

相关链接：[Google: 网页字体优化](https://developers.google.com/web/fundamentals/performance/optimizing-content-efficiency/webfont-optimization?hl=zh-cn)

*字体受版权保护，若在网页中使用商业字体，请联系相关字体厂商购买授权*
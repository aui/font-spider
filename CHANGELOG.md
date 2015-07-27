# 更新日志

## 0.3.2

* 支持 https 远程资源

## 0.3.1

* 支持 gzip 远程资源

## 0.3.0

* 重构爬虫模块，解决压缩后的 CSS 解析失败的问题
* font 属性缩写支持、多个@font-face同名字体支持 #32
* 改进错误流程处理：HTML、CSS 加载与解析错误都会进入错误流程
* 提供对外接口

## 0.2.1

* 避免部分字体转码失败导致程序崩溃的问题 [#28](https://github.com/aui/font-spider/issues/28)
* 使用隐藏目录`.font-spider`备份字体

## 0.2.0

* 使用 fontmin 取代字蛛内置的压缩与转码模块，让压缩后的字体更小，并且无需 Perl 环境 [#18](https://github.com/aui/font-spider/issues/18)
* 优化爬虫模块，使用更高效的 cheerio 代替 jsdom 解析 HTML
* 支持解析远程动态页面，可结合`map`参数映射线上 CSS 与 WebFont 资源到本地
* 实现对 CSS `:before`与`:after`定义`content`的支持（不支持继承的字体）

## 0.1.1

* 修复和最新版 NodeJS 兼容问题

## 0.1.0

* 优化错误信息显示
* 支持`map`配置映射 CSS 文件中的 http 路径到本地目录
* 支持`ignore`配置忽略字体、CSS、HTML 文件
  
## 0.0.1

* 基于 CSS 规则压缩与转码 WebFont
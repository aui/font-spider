# 字蛛更新日志

## 1.3.1

* 支持 `input[placeholder]` 内容 [#99](https://github.com/aui/font-spider/issues/99)
* 修复字体压缩后在 IE 下 `<br>` 标签显示乱码的问题 [#91](https://github.com/aui/font-spider/issues/91)

## 1.3.0

* 支持 otf 格式（不完善）

## 1.2.0

* 在终端增加嵌入字体的字符数量的显示

## 1.1.3

* 修复使用 `!important` 后计算 `font-family` 最终值计算不正确的 BUG
* 支持 `font-family` 关键字 `serif`、`sans-serif`、`monospace`、`cursive`、`fantasy`、`initial`、`inherit`

## 1.1.2

* 修复 `font` 缩写的 BUG

## 1.1.1

* 添加 debug 参数
* 修复多行选择器可能导致查询的文本缺失的 BUG
* 修复无字符的时候，压缩器无限等待的 BUG

## 1.1.0

* 添加对 woff2 格式字体支持

## 1.0.1

* 对不支持的字体格式抛异常
* 修复命令行工具遇到空 WebFonts 的时候报错

## 1.0.0

* 重构爬虫模块，使用 [browser-x](https://github.com/aui/browser-x) 来虚拟浏览器环境
* 支持伪元素 `content` 继承的字体，进而支持了采用此的图标字体库
* 支持伪元素 `content: 'prefix'` 和 `content: attr(value)` 模式
* 支持行内样式的 `font-family` 解析
* 提供新的 API、更好的支持远程资源解析
* 大幅度提高运行速度 
* 修复 CSS `font-weight` 可能导致遗漏字符的 BUG [#62](https://github.com/aui/font-spider/issues/62)
* 修复设置 `font-family: inherit` 可能遗漏字符的 BUG [#44](https://github.com/aui/font-spider/issues/44)
* 修复 Windows 下使用通配符路径报错的 BUG [#58](https://github.com/aui/font-spider/issues/58)
* 修复 OSX 表情字符无法解析的 BUG [#59](https://github.com/aui/font-spider/issues/59)
* 修复 CSS `content` 属性不支持 unicode 属性值的 BUG
* 修复 `<base href="#">` 设置可能导致资源加载失败的 BUG [#63](https://github.com/aui/font-spider/issues/63)
* 修复 `ignore` 配置参数无法处理远程路径的 BUG，同时规则不再支持 `*` 号形式，请使用正则代替
* 修复 `map` 与 `ignore` 配置参数在 Windows 反斜杠匹配的问题

## 0.3.8

* 修复 CSS `@charset` 可能导致无法解析的 BUG

## 0.3.7

* 完善伪类选择器支持
* 给部分不支持的 CSS 规则显示警告信息

## 0.3.6

* 修复 BUG [#43](https://github.com/aui/font-spider/issues/43)
* 提高程序稳定性

## 0.3.5

* 升级 fontmin 版本
* 命令行工具兼容旧版本 NodeJS

## 0.3.4

* 升级 fontmin 版本
* 使用 `'accept-encoding': 'gzip,deflate'` 请求远程资源
* 优化终端错误显示

## 0.3.3

* 修复命令行没有显示错误的 BUG

## 0.3.2

* 支持 https 远程资源

## 0.3.1

* 支持 gzip 远程资源

## 0.3.0

* 重构爬虫模块，解决压缩后的 CSS 解析失败的问题
* font 属性缩写支持、多个 `@font-face` 同名字体支持 #32
* 改进错误流程处理：HTML、CSS 加载与解析错误都会进入错误流程
* 提供对外接口

## 0.2.1

* 避免部分字体转码失败导致程序崩溃的问题 [#28](https://github.com/aui/font-spider/issues/28)
* 使用隐藏目录 `.font-spider` 备份字体

## 0.2.0

* 使用 fontmin 取代字蛛内置的压缩与转码模块，让压缩后的字体更小，并且无需 Perl 环境 [#18](https://github.com/aui/font-spider/issues/18)
* 优化爬虫模块，使用更高效的 cheerio 代替 jsdom 解析 HTML
* 支持解析远程动态页面，可结合 `map` 参数映射线上 CSS 与 WebFont 资源到本地
* 实现对 CSS `::before` 与 `::after` 定义 `content` 的支持（但不支持继承的字体）

## 0.1.1

* 修复和最新版 NodeJS 兼容问题

## 0.1.0

* 优化错误信息显示
* 支持 `map` 配置映射 CSS 文件中的 http 路径到本地目录
* 支持 `ignore` 配置忽略字体、CSS、HTML 文件
  
## 0.0.1

* 基于 CSS 规则压缩与转码 WebFont
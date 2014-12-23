#	字蛛

中文字体自动化压缩工具。官方网站：<http://font-spider.org>

## 特性

1. 轻巧：数 MB 的中文字体可被压成几十 KB
2. 简单：完全基于 CSS，无需 js 与服务端支持
3. 兼容：自动转码，支持 IE 与标准化的浏览器
4. 自然：文本支持选中、搜索、翻译、朗读、缩放

## 原理

字蛛通过分析本地 CSS 与 HTML 文件获取 WebFont 中没有使用的字符，并将这些字符数据从字体中删除以实现压缩，并生成跨浏览器使用的格式。

1. 构建 CSS 语法树，分析字体与选择器规则
2. 使用包含 WebFont 的 CSS 选择器索引站点的文本
3. 匹配字体的字符数据，剔除无用的字符
4. 编码成跨浏览器使用的字体格式

##	安装

安装好 [nodejs](http://nodejs.org)，然后执行：

```
npm install font-spider -g
```

> * windows 需要安装 [perl](http://www.perl.org) 环境才可以运行。
> * GruntJS 用户可使用 [gruntjs 插件](file:///Users/tangbin/Documents/github/font-spider-website/install.html)。

##	使用范例

### 在 CSS 中声明字体

```
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

> 1. ``@font-face``中的``src``定义的 .ttf 文件必须存在，其余的格式将由工具自动生成
> 2. 开发阶段请使用相对路径的 CSS 与 WebFont
> 3. 不支持动态插入的 CSS 规则与字符
> 4. 不支持 CSS ``content``属性插入的字符

###	压缩 WebFont

```
font-spider 1.html 2.html 3.html
```

> * 支持通配符，例如：``font-spider dest/*.html``

##	字体兼容性参考

格式 | IE | Firefox | Chrome | Safari | Opera | iOS Safari | Android Browser | Chrome for Android 
----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | -----
``.eot`` | 6  | -- | -- | -- | -- | -- | -- | --
``.woff`` | 9 | 3.6 | 5 | 5.1 | 11.1 | 5.1 | 4.4 | 36 
``.ttf`` | --  | 3.5 | 4 | 3.1 | 10.1 | 4.3 | 2.2 | 36
``.svg`` | -- | -- | 4 | 3.2 | 9.6 | 3.2 | 3 | 36

来源：<http://caniuse.com/#feat=fontface>

## 贡献者

* [@糖饼](http://www.weibo.com/planeart)
* [@fufu](http://www.weibo.com/u/1715968673)
* [@kdd](http://www.weibo.com/kddie)


=============

*字体受版权保护，若在网页中使用商业字体，请联系相关字体厂商购买授权*

[![NPM](https://nodei.co/npm/font-spider.png?downloads=true&stars=true)](https://nodei.co/npm/font-spider/)
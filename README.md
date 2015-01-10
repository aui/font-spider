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
> * GruntJS 用户可使用 [gruntjs 插件](https://github.com/aui/grunt-font-spider)。

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
> 2. 不支持动态插入的 CSS 规则与字符
> 3. 不支持 CSS ``content``属性插入的字符

###	压缩 WebFont

```
font-spider [options] <htmlFile ...>
```

> 支持通配符，例如：``font-spider dest/*.html``

#### Options

```
-h, --help                    输出帮助信息
-V, --version                 输出当前版本号
--info                        仅提取 WebFont 信息显示，不压缩与转码
--ignore <pattern>            忽略的文件配置（可以是字体、CSS、HTML）
--map <remotePath,localPath>  映射 CSS 内部 HTTP 路径到本地
--debug                       开启调试模式
--no-backup                   关闭字体备份功能
--silent                      不显示非关键错误
--revert                      恢复被压缩的 WebFont
```


##	字体兼容性参考

格式 | IE | Firefox | Chrome | Safari | Opera | iOS Safari | Android Browser | Chrome for Android 
----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | -----
``.eot`` | 6  | -- | -- | -- | -- | -- | -- | --
``.woff`` | 9 | 3.6 | 5 | 5.1 | 11.1 | 5.1 | 4.4 | 36 
``.ttf`` | --  | 3.5 | 4 | 3.1 | 10.1 | 4.3 | 2.2 | 36
``.svg`` | -- | -- | 4 | 3.2 | 9.6 | 3.2 | 3 | 36

来源：<http://caniuse.com/#feat=fontface>

## 更新日志

### 0.1.0

  * 优化错误信息显示
  * 支持``map``配置映射 CSS 文件中的 http 路径到本地目录
  * 支持``ignore``配置忽略字体、CSS、HTML 文件
  
### 0.0.1

  * 基于 CSS 规则压缩与转码 WebFont

## 贡献者

* [@糖饼](http://www.weibo.com/planeart)
* [@fufu](http://www.weibo.com/u/1715968673)
* [@kdd](http://www.weibo.com/kddie)


=============

*字体受版权保护，若在网页中使用商业字体，请联系相关字体厂商购买授权*

[![NPM](https://nodei.co/npm/font-spider.png?downloads=true&stars=true)](https://nodei.co/npm/font-spider/)
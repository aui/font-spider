# font-spider

[![NPM Version][npm-image]][npm-url]
[![NPM Downloads][downloads-image]][downloads-url]
[![Node.js Version][node-version-image]][node-version-url]
[![Build Status][travis-ci-image]][travis-ci-url]

Font-spider is a compress tool for WebFont which can analyze your web-page intelligently to find the fonts out which have been used and then compress them.

字蛛是一个智能 WebFont 压缩工具，它能自动分析出页面使用的 WebFont 并进行按需压缩。[[中文文档]](./README-ZH-CN.md)

Website: <http://font-spider.org>

<img alt="font-spider" width="670" src="https://cloud.githubusercontent.com/assets/1791748/15415184/8bc574ac-1e73-11e6-92b9-515281620e9d.png">

## feature

1. font subsetter: our tool is based on HTML and CSS analysis and completely running in local so that
2. font converter: Support woff2, woff, eot, svg font format generation

## install

``` shell
npm install font-spider -g
```

## use

### step one: code CSS

``` css
@font-face {
  font-family: 'pingfang';
  src: url('../font/pingfang.eot');
  src:
    url('../font/pingfang.eot?#font-spider') format('embedded-opentype'),
    url('../font/pingfang.woff2') format('woff2'),
    url('../font/pingfang.woff') format('woff'),
    url('../font/pingfang.ttf') format('truetype'),
    url('../font/pingfang.svg') format('svg');
  font-weight: normal;
  font-style: normal;
}

.home h1, .demo > .test {
    font-family: 'pinghei';
}
```

> attention: the .ttf file must be existed which is referred in `src` property of `@font-face`, and our font-spider will automatically generate other formats of font.

### step two: compress WebFont by using font-spider

``` shell
font-spider [options] <htmlFile1 htmlFile2 ...>
```

#### htmlFiles

one or more web-page addresses which support the http form.

example:

``` shell
font-spider dest/news.html dest/index.html dest/about.html
```

> if there were several pages depend on the same fonts, please use `--htmlFiles` to transfer them in.

#### options

```
Usage: font-spider [options] <htmlFile ...>

Options:

  -h, --help                    output usage information
  -V, --version                 output the version number
  --info                        show only webfont information
  --ignore <pattern>            ignore the files
  --map <remotePath,localPath>  mapping the remote path to the local
  --no-backup                   do not back up fonts
  --debug                       enable debug mode
```

#### sample of parameters usage

use the wildcard character to compress the WebFont of several HTML file

``` shell
font-spider dest/*.html
```

`--info` show the WebFont that has been used on the website：

``` shell
font-spider --info http://fontawesome.io
```

`--ignore` ignore the file：

``` shell
font-spider --ignore "icon\\.css$" dest/*.html
```

`--map` this parameter will map the WebFont of online page to local and then compress it (the local path must be an absolute path)：

``` shell
font-spider --map "http://font-spider.org/font,/Website/font" http://font-spider.org/index.html
```

## build plugins

- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

## API

font-spider include the crawler and the compressor module, API docs：[API.md](./API.md)

## restrict

- only the constant texts and styles are supported, but not the dynamic elements and styles which is inserted by javascript
- the .otf format fonts should be transfered to .ttf format firstly, so that we can start our compressing work
- only the HTML and CSS files which is encoded by `utf-8` are supported.

[npm-image]: https://img.shields.io/npm/v/font-spider.svg
[npm-url]: https://npmjs.org/package/font-spider
[node-version-image]: https://img.shields.io/node/v/font-spider.svg
[node-version-url]: http://nodejs.org/download/
[downloads-image]: https://img.shields.io/npm/dm/font-spider.svg
[downloads-url]: https://npmjs.org/package/font-spider
[travis-ci-image]: https://travis-ci.org/aui/font-spider.svg?branch=master
[travis-ci-url]: https://travis-ci.org/aui/font-spider
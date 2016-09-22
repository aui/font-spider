# font-spider 

[![NPM Version][npm-image]][npm-url]
[![NPM Downloads][downloads-image]][downloads-url]
[![Node.js Version][node-version-image]][node-version-url]
[![Build Status][travis-ci-image]][travis-ci-url]

[[简体中文]](./README-ZH-CN.md) | [[English]](./README.md) | [[日本語]](./README-JA.md)

フォント・スパイダー（font-spider）は、Webフォントを圧縮するためのスマートなツールです，Webページに使用されるWebフォントを分析し、必要に応じて圧縮することができます。

公式サイト：<http://font-spider.org>

## 特徴

1. 必要に応じて圧縮：不必要なグリフを削除し、小さなフォントファイルを圧縮することができます。
2. ローカル処理：ローカルHTMLとCSSファイルの分析に基づいて、JavaScriptとサーバー側のサポートの必要はありません。
3. 自動トランスコーディング：すべてのブラウザでサポートされているフォントファイルに変換することができます。

## インストール

[nodejs](http://nodejs.org)のインストールを完了した後、以下のコードを実行します：

``` shell
npm install font-spider -g
```

## 使用例

### 一、CSSコード

``` css
/*CSSの記述*/
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

/*フォントを選ぶ*/
.home h1, .demo > .test {
    font-family: 'pinghei';
}
```

> 特記： `@font-face` の中の `src` で記述の .ttf ファイル存在している必要があります、残りのフォーマットは font-spider が自動自動的に生成することができます。

### 二、Webフォントを圧縮

``` shell
font-spider [options] <htmlFile1 htmlFile2 ...>
```

#### htmlFiles

一つ或いは一つ以上のページアドレス、HTTP形式はサポートされています。

例えば：

``` shell
font-spider dest/news.html dest/index.html dest/about.html
```

> 複数のページが同じフォントを使用している場合、`--htmlFiles` を使ってください

#### options

``` shell
-h, --help                    ヘルプ情報の出力
-V, --version                 現在のバージョンの出力
--info                        WebフォントのJSON情報の出力、圧縮とトランスコーディングなし
--ignore <pattern>            無視している設定ファイル（正規表現をサポートしています）
--map <remotePath,localPath>  CSS内部のHTTPパスがローカルへのマッピング
--no-backup                   フォントファイルのバックアップなし
--debug                       デバッグモード
```

#### パラメータの例

ワイルドカードを使用して複数のHTMLファイル関連するWEBフォントの圧縮：

``` shell
font-spider dest/*.html
```

`--info` で全サイトのWEBフォントをチェックする：

``` shell
font-spider --info http://fontawesome.io
```

`--ignore` ファイルの無視：

``` shell
font-spider --ignore "icon\\.css$" dest/*.html
```

`--map` オンラインページのWEBフォントがローカルにマッピングして圧縮する（ローカルパスは絶対パスが必要）：

``` shell
font-spider --map "http://font-spider.org/font,/Website/font" http://font-spider.org/index.html
```

## プラグインの構築

- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

## API

フォント・スパイダーはクローラーと圧縮モジュールが含みます、APIのドキュメント：[API.md](./API.md)

## 制限

- 固定的なテキストとスタイルのみをサポートされて、JavaScriptのによって挿入動的な要素とスタイルがサポートされていません。
- OpenTypeのフォントのサポートが不完全です。
-  `utf-8`のHTMLとCSSのみをサポートされています。
- CSS の`content`プロパティはプレーンテキストのみをサポートされて、プロパティやカウンターなどの機能をサポートされていません。

## 関連リンク

- [TTF版の源ノ角ゴシック](https://mega.nz/#!PZxFSYQI!ICvNugaFX_y4Mh003-S3fao1zU0uNpeSyprdmvHDnwc)
- [grunt-font-spider](https://github.com/aui/grunt-font-spider)
- [gulp-font-spider](https://github.com/aui/gulp-font-spider)

[npm-image]: https://img.shields.io/npm/v/font-spider.svg
[npm-url]: https://npmjs.org/package/font-spider
[node-version-image]: https://img.shields.io/node/v/font-spider.svg
[node-version-url]: http://nodejs.org/download/
[downloads-image]: https://img.shields.io/npm/dm/font-spider.svg
[downloads-url]: https://npmjs.org/package/font-spider
[travis-ci-image]: https://travis-ci.org/aui/font-spider.svg?branch=master
[travis-ci-url]: https://travis-ci.org/aui/font-spider
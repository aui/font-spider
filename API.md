# font-spider API 文档

``` javascript
var fontSpider = require('font-spider');
```

## fontSpider

分析字体依赖并压缩字体。内部依次执行 `fontSpider.spider()` 与 `fontSpider.compressor()`

``` javascript
/**
 * @param   {Array<String>}     网页路径列表
 * @param   {Object}            选项
 * @param   {Function}          回调函数
 * @return  {Promise}           接收 `WebFonts` 描述信息
 */
fontSpider(htmlFiles, options, callback)
```

## fontSpider.spider

查找页面所使用的字体，得到 WebFonts 描述信息

``` javascript
/**
 * @param   {Array<String>}     网页路径列表
 * @param   {Object}            选项
 * @return  {Promise}           接收 `WebFonts` 描述信息
 */
fontSpider.spider(htmlFiles, options)
```

## fontSpider.compressor

压缩、转码字体

``` javascript
/**
 * @param   {Array<WebFont>}    `WebFonts` 描述信息
 * @param   {Object}            选项
 * @return  {Promise}           接收 `WebFonts` 描述信息
 */
fontSpider.compressor(webFonts, options)
```

## 示例

fontSpider.spider + fontSpider.compressor

``` javascript
var fontSpider = require('font-spider');

fontSpider.spider([__diranme + '/index.html'], {
    silent: false
}).then(function(webFonts) {
    return fontSpider.compressor(webFonts, {backup: true});
}).then(function(webFonts) {
    console.log(webFonts);
}).catch(function(errors) {
    console.error(errors);
});
```

## 选项

``` javascript
{
    /**
     * 忽略加载的文件规则 - 与 `resourceIgnore` 参数互斥
     * @see     https://github.com/kaelzhang/node-ignore
     * @type    {Array<String>}
     */
    ignore: [],

    /**
     * 映射的文件规则 - 与 `resourceMap` 参数互斥 - 可以将远程字体文件映射到本地来（支持正则）
     * @type    {Array<Array<String>>}
     * @example [['http://font-spider.org/font', __diranme + '/font'], ...]
     */
    map: [],

    /**
     * 是否支持备份原字体
     * @type    {Boolean}
     */
    backup: true,

    /**
     * 是否对查询到的文本进行去重处理
     * @type    {Boolean}
     */
    unique: true,

    /**
     * 是否排序查找到的文本
     * @type    {Boolean}
     */
    sort: true,

    /**
     * 是否支持加载外部 CSS 文件
     */
    loadCssFile: true,

    /**
     * 是否忽略内部解析错误-关闭它有利于开发调试
     * @type    {Boolean}
     */
    silent: true,

    /**
     * 请求超时限制
     * @type    {Number}    毫秒
     */
    resourceTimeout: 8000,

    /**
     * 最大的文件加载数量限制
     * @type    {Number}    数量
     */
    resourceMaxNumber: 64,

    /**
     * 是否缓存请求成功的资源
     * @type    {Boolean}
     */
    resourceCache: true,

    /**
     * 映射资源路径 - 与 `map` 参数互斥
     * @param   {String}    旧文件地址
     * @return  {String}    新文件地址
     */
    resourceMap: function(file) {},

    /**
     * 忽略资源 - 与 `ignore` 参数互斥
     * @param   {String}    文件地址
     * @return  {Boolean}   如果返回 `true` 则忽略当当前文件的加载
     */
    resourceIgnore: function(file) {},

    /**
     * 资源加载前的事件
     * @param   {String}    文件地址
     */
    resourceBeforeLoad: function(file) {},

    /**
     * 加载远程资源的自定义请求头
     * @param   {String}    文件地址
     * @return  {Object}
     */
    resourceRequestHeaders: function(file) {
        return {
            'accept-encoding': 'gzip,deflate'
        };
    }
}
```


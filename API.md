# font-spider 接口文档

``` javascript
var fontSpider = require('font-spider');
```

## 接口

### fontSpider.spider()

字体查询器。获取 WebFonts 描述信息

``` javascript
/**
 * @param   {Array<String>}     网页路径列表
 * @param   {Object}            选项
 * @param   {Function}          回调函数。接收 `WebFonts` 描述信息
 * @return  {Promise}           如果没有 `callback` 参数则返回 `Promise` 对象
 */
fontSpider.spider(htmlFiles, options, callback)
```

### fontSpider.compressor()

字体压缩转码器。根据 WebFonts 描述信息来处理字体文件

``` javascript
/**
 * @param   {Array<WebFont>}    `WebFonts` 描述信息
 * @param   {Object}            选项
 * @param   {Function}          回调函数。接收 `WebFonts` 描述信息
 * @return  {Promise}           如果没有 `callback` 参数则返回 `Promise` 对象
 */
fontSpider.compressor(webFonts, options, callback)
```

## 示例

压缩字体，并显示描述信息：

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
     * 忽略加载的文件规则（支持正则） - 与 `resourceIgnore` 参数互斥
     * @type    {Array<String>}
     */
    ignore: [],

    /**
     * 映射的文件规则（支持正则） - 与 `resourceMap` 参数互斥 - 可以将远程字体文件映射到本地来
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
     * 是否开启调试模式
     * @type    {Boolean}
     */
    debug: false,

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

## 调试

字体处理不准确？可能有 CSS 加载或解析错误被忽略，可以设置 `silent: false, debug: true` 来调试。

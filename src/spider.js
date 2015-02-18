'use strict';

var fs = require('fs');
var path = require('path');
var http = require('http');
var url = require('url');
var css = require('css');
var ignore = require('ignore');
var cheerio = require('cheerio');
var Promise = require('promise');


// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;


var Spider = function (htmlFiles, options, callback) {

    options = this._getOptions(options);
    callback = callback || function () {};


    if (typeof htmlFiles === 'string') {
        htmlFiles = [htmlFiles];
    }

    
    var that = this;
    var promiseList = [];


    this._fontsCache = {};
    this._charsCache = {};
    this._fileCache = {};
    this._cssParserCache = {};

    this.options = options;

    this._ignore = ignore({
        ignore: options.ignore
    });


    htmlFiles = this._ignore.filter(htmlFiles);

   
    htmlFiles.forEach(function (htmlFile) {
        promiseList.push(that._htmlParser(htmlFile));
    });


    return Promise.all(promiseList)
    .then(function (contents) {


        var list = [];
        var files = this._fontsCache;
        var chars = this._charsCache;
        var that = this;

        function sort (a, b) {
            return a.charCodeAt() - b.charCodeAt();
        }


        // 数组除重复
        function unique (array) {
            var ret = [];

            array.forEach(function (val) {
                if (ret.indexOf(val) === -1) {
                    ret.push(val);
                }
            });

            return ret;
        };

        
        Object.keys(chars).forEach(function (familyName) {
            
            var strings = chars[familyName].split('');

            // 对字符进行除重操作
            if (options.unique) { 
                strings = unique(strings);
            }

            // 对字符按照编码进行排序
            if (options.sort) {
                strings.sort(sort);
            }
            
            strings = strings.join('');

            // 删除无效字符
            strings = strings.replace(/[\n\r\t]/g, '');

            
            chars[familyName] = strings;
        });


        Object.keys(files).forEach(function (familyName) {
            if (chars[familyName]) {
                list.push({
                    name: familyName,
                    chars: chars[familyName],
                    files: files[familyName]
                });
            }
        });
        

        callback(null, list);

        return list;
    }.bind(this))

    .then(null, function (errors) {
        callback(errors);
        console.error(errors && errors.stack || errors);
        return errors;
    });

};


Spider.defaults = {
    debug: false,
    silent: false,
    sort: true,
    unique: true,
    ignore: [],
    map: []
};







Spider.prototype = {

    constructor: Spider,




    /*
     * 文件对象构造器
     * @param   {String}        文件绝对路径
     * @param   {String}        文件内容
     * @param   {Object}        file, content
     */
    _File: function (file, content) {
        this.file = file;
        this.content = content;
    },




    /*
     * 获取文件对象。注意：读取错误的文件会返回空字符串，不会进入错误流程
     * @param   {String}                                文件绝对路径
     * @param   {String}                                调用此功能的源文件（供调试）
     * @param   {Number}                                调用此功能的源文件所在行数（供调试）
     * @return   {Spider.prototype._File, Promise}      文件对象
     */
    _getFile: function (file, isCache, sourceFile, sourceLine) {

        file = this._normalize(file);

        var that = this;
        var cache = this._fileCache[file];
        var ret;

        if (sourceFile) {
            sourceFile = sourceFile + (sourceLine ? (':' + sourceLine) : '');
        }


        if (cache) {

            return cache;
        
        } else {

            ret = new Promise(function (resolve, reject) {

                // 远程文件
                if (RE_SERVER.test(file)) {

                    http.get(file, function (res) {

                        var size = 0;
                        var chunks = [];

                        res.on('data', function (chunk) {
                            size += chunk.length;
                            chunks.push(chunk);
                        });

                        res.on('end', function () {
                            var data = Buffer.concat(chunks, size);

                            var content = data.toString();

                            that._log('[GET] OK', file);
                            resolve(new that._File(file, content));
                        });

                    })
                    .on('error', function (errors) {
                        if (sourceFile) {
                            that._error('Source: ' + sourceFile);
                        }

                        that._error('Error: get "' + file + '" failed\n');

                        resolve(new that._File(file, ''));
                    });


                // 本地文件
                } else {

                    fs.readFile(file, 'utf8', function (errors, content) {

                        if (errors) {

                            if (sourceFile) {
                                that._error('Source: ' + sourceFile);
                            }

                            that._error('Error: read "' + file + '" failed\n');

                            resolve(new that._File(file, ''));
                        } else {

                            that._log('[READ] OK', file);
                            resolve(new that._File(file, content));
                        }

                    });

                }
            });

        }


        if (isCache) {
            this._fileCache[file] = ret;
        }


        return ret;
    },



    /*
     * 转换到绝对路径，支持 HTTP 形式
     * @param   {String}    来源路径
     * @param   {String}    子路径
     * @return  {String}    绝对路径
     */
    _resolve: function (from, to) {
        if (RE_SERVER.test(from)) {
            return url.resolve(from, to);
        } else if (RE_SERVER.test(to)) {
            return to;
        } else {
            return path.resolve(from, to);
        }
    },



    _normalize: function (uri) {

        // ../font/font.eot?#font-spider
        var RE_QUERY = /[#?].*$/g;

        if (RE_SERVER.test(uri)) {
            return uri;
        } else {
            return uri.replace(RE_QUERY, ''); 
        }
    },


    /*
     * 解析 HTML 
     * @param   {String}            文件绝对路径
     * @return  {}
     */
    _htmlParser: function (htmlFile) {


        //htmlFile = path.resolve(htmlFile);
        
        var $;
        var that = this;
        
        
        var base = path.dirname(htmlFile);


        return this._getFile(htmlFile, false)


        // 查找页面中的样式内容
        // 如 link 标签与页面内联 style 标签

        .then(function (data) {
            
            var htmlContent = data.content;

            $ = cheerio.load(htmlContent);

            var styleSheets = $('link[rel=stylesheet], style');
            var cssContents = [];

            // TODO base 标签顺序影响
            base = $('base[href]').attr('href') || base;


            // 查询并读取页面中所有样式表
            styleSheets.each(function (index, element) {

                var $this = $(this);
                var cssInfo;
                var cssFile;
                var href = $this.attr('href');
                var cssContent = '';


                // 忽略含有有 disabled 属性的
                if ($this.attr('disabled') && $this.attr('disabled') !== 'false') {

                    return;
                }

                if (!that._ignore.filter([href]).length) {

                    return;
                }
                

                // link 标签
                if (href) {

                    href = that._map(href);

                    cssFile = that._resolve(base, href);

                    cssContent = that._getFile(cssFile, true, htmlFile);
                    


                // style 标签
                } else {
                    cssContent = new that._File(htmlFile, $this.text());
                }


                cssContents.push(cssContent);

            });
            


            return Promise.all(cssContents);
        })
    

        // 解析样式表

        .then(function (cssContents) {

            var cssInfos = [];

            cssContents.forEach(function (item) {
                var cssContent = item.content;
                var cssFile = item.file;
                var cssInfo = that._cssParser(cssContent, cssFile);
                cssInfos.push(cssInfo);
            });

            return Promise.all(cssInfos);
        })


        // 根据选择器查询 HTML 节点

        .then(function (cssInfos) {

            var RE_SPURIOUS = /\:(link|visited|hover|active|focus)\b/ig;

            var eachSelectors = function (selectors) {

                var rules = selectors.rules.join(', ');
                selectors.familys.forEach(function (family) {

                    if (!that._fontsCache[family]) { // TODO 这一句可能因为顺序问题产生BUG
                        return;
                    }

                    that._charsCache[family] = that._charsCache[family] || '';

                    // 剔除状态伪类
                    rules = rules.replace(RE_SPURIOUS, '');

                    try {
                        var elements = $(rules);
                    } catch (e) {
                        // 1. 包含 :before 等不支持的伪类
                        // 2. 非法语句
                        return;
                    }

                    that._log('[INFO]', family, rules);
                    
                    elements.each(function (index, element) {

                        // 找到使用了字体的文本
                        that._charsCache[family] += $(element).text();

                    });
                });


            };


            cssInfos.forEach(function (cssInfo) {

                cssInfo.fonts.forEach(function (item) {
                    that._fontsCache[item.name] = item.files;
                });

                // 提取 HTML 的文本
                cssInfo.selectors.forEach(eachSelectors);

                //that._log('[CSS]', JSON.stringify(cssInfo, null, 4));

            });


        });
        
    },

    _getOptions: function (options) {
        var ret = {};

        options = options || {};

        Object.keys(Spider.defaults).forEach(function (key) {
            ret[key] = Spider.defaults[key];
            if (options[key] !== undefined) {
                ret[key] = options[key];
            }
        });


        ret.map = ret.map.map(function (params) {
            if (typeof params[0] === 'string') {
                params[0] = new RegExp(params[0]);
            }
            return params;
        });


        return ret;
    },



    // 根据正则替换 URL
    _map: function (uri) {
        var regs = this.options.map;

        if (!regs || !regs.length) {
            return uri;
        }

        if (!Array.isArray(regs[0])) {
            regs = [regs];
        }

        regs.forEach(function (reg) {
            uri = uri.replace.apply(uri, reg);
        });

        return uri;
    },



    // 提取 css 中要用到的信息
    _cssParser: function (string, filename) {

        // url(../font/font.ttf)
        // url("../font/font.ttf")
        // url('../font/font.ttf')
        var RE_URL = /url\((.*?)\)/ig;

        // "../font/font.ttf"
        // '../font/font.ttf'
        var RE_QUOTATION = /^['"]|['"]/g;

        // !important
        var RE_IMPORTANT = /!important[\s\t]*$/i;

        // art, lanting, heiti
        var RE_SPLIT_COMMA = /\s*,\s*/;


        var that = this;
        var cache = this._cssParserCache[filename];
        var base = path.dirname(filename);
        var importInfo = null;


        if (cache) {
            return cache;
        }


        // 字体文件信息
        var fonts = [];

        // 选择器信息
        var selectors = [];

        try {
            var ast = css.parse(string);
        } catch (e) {

            that._error('Source: ' + filename);

            if (e.line !== undefined) {
                that._error(e.toString() + '\n');
            } else if (e.stack) {
                that._error(e.stack + '\n');
            }

            return {
                fonts: [],
                selectors: []
            };
        }


        var parser = function (rule) {

            var position = rule.position;

            switch (rule.type) {

                case 'import':
                    
                    
                    var url = rule['import'];
                    

                    // @import url("./g.css?t=2009");
                    // @import "./g.css?t=2009";
                    if (RE_URL.test(url)) {
                        RE_URL.lastIndex = 0;
                        url = RE_URL.exec(url)[1];
                    }

                    url = url.replace(RE_QUOTATION, '');

                    if (!that._ignore.filter([url]).length) {
                        break;
                    }

                    url = that._map(url);

                    var target = that._resolve(base, url);
                    var line = position ? position.start.line : null;
                    
                    importInfo = that._getFile(target, true, filename, line)
                    .then(function (data) {
                        var cssContent = data.content;
                        var cssInfo = that._cssParser(cssContent, target);
                        return cssInfo;
                    })
                    .then(function (cssInfo) {
                        return {
                            fonts: fonts.concat(cssInfo.fonts),
                            selectors: selectors.concat(cssInfo.selectors)
                        }
                    });

                    break;

                case 'font-face':

                    var family = {
                        name: '',
                        files: []
                    };

                    rule.declarations.forEach(function (declaration) {

                        var property = declaration.property;
                        var value = declaration.value;

                        if (property) {
                            property = property.toLocaleLowerCase();
                        }

                        switch (property) {
                            case 'font-family':

                                value = value
                                .replace(RE_IMPORTANT, '')
                                .replace(RE_QUOTATION, '')
                                .trim();

                                family.name = value;
                                
                                break;

                            case 'src':
                                var url;

                                RE_URL.lastIndex = 0;
                                while ((url = RE_URL.exec(value)) !== null) {

                                    url = url[1];
                                    url = url.replace(RE_QUOTATION, '');
                                    url = that._map(url);
                                    url = that._normalize(url);
                                    url = that._resolve(base, url);

                                    if (family.files.indexOf(url) === -1) {
                                        family.files.push(url);
                                    }
                                }

                                break;
                        }
                    });


                    if (family.name) {
                        family.files = that._ignore.filter(family.files);
                        fonts.push(family);
                    }


                    break;

                case 'media':

                    rule.rules.forEach(parser);
                    break;

                case 'rule':

                    var selector = {
                        rules: rule.selectors,// 注意：包含伪类选择器
                        familys: []
                    };


                    rule.declarations.forEach(function (declaration) {

                        var property = declaration.property;
                        var value = declaration.value;

                        if (property) {
                            property = property.toLocaleLowerCase()
                        }

                        switch (property) {
                            case 'font-family':

                                value.split(RE_SPLIT_COMMA).forEach(function (val) {
                                    // 去掉空格与前后引号
                                    val = val
                                    .replace(RE_IMPORTANT, '')
                                    .replace(RE_QUOTATION, '')
                                    .trim();


                                    selector.familys.push(val);
                                });
                                
                                break;

                            case 'content':
                                // TODO
                                break;
                        }
                    });


                    if (selector.familys.length) {
                        selectors.push(selector);
                    }

                    break;
            }

        };

        ast.stylesheet.rules.forEach(parser);


        return this._cssParserCache[filename] = importInfo || {
            fonts: fonts,
            selectors: selectors
        };
    },

    _error: function () {
        if (!this.options.silent || this.options.debug) {
            console.error.apply(console, arguments);
        }
    },

    _log: function () {
        if (this.options.debug) {
            console.log.apply(console, arguments);
        }
    }
};


module.exports = Spider;


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

    options = this.getOptions(options);
    callback = callback || function () {};


    if (typeof htmlFiles === 'string') {
        htmlFiles = [htmlFiles];
    }

    
    var that = this;
    var promiseList = [];


    this.fontsCache = {};
    this.charsCache = {};
    this.fileCache = {};
    this.cssParserCache = {};

    this.options = options;


    this.ignore = ignore({
        ignore: options.ignore
    });


    htmlFiles = this.filter(htmlFiles);

   
    htmlFiles.forEach(function (htmlFile) {
        promiseList.push(that.htmlParser(htmlFile));
    });


    return Promise.all(promiseList)
    .then(function (contents) {


        var list = [];
        var files = this.fontsCache;
        var chars = this.charsCache;
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
    File: function (file, content) {
        this.file = file;
        this.content = content;
    },




    /*
     * 获取文件对象。注意：读取错误的文件会返回空字符串，不会进入错误流程
     * @param   {String}                                文件绝对路径
     * @param   {String}                                调用此功能的源文件（供调试）
     * @param   {Number}                                调用此功能的源文件所在行数（供调试）
     * @return   {Spider.prototype.File, Promise}      文件对象
     */
    getFile: function (file, sourceFile, sourceLine) {

        var that = this;
        var isCache = true; 
        var cache = this.fileCache[file];
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

                            that.info('[GET]', 'OK', file);
                            resolve(new that.File(file, content));
                        });

                    })
                    .on('error', function (errors) {

                        var err = ['Error: get "' + file + '" failed'];
                        if (sourceFile) {
                            err.push('Source: ' + sourceFile);
                        }

                        that.error(err.join('\n'));

                        resolve(new that.File(file, ''));
                    });


                // 本地文件
                } else {

                    fs.readFile(file, 'utf8', function (errors, content) {

                        if (errors) {

                            var err = ['Error: read "' + file + '" failed'];
                            if (sourceFile) {
                                err.push('Source: ' + sourceFile);
                            }

                            that.error(err.join('\n'));

                            resolve(new that.File(file, ''));
                        } else {

                            that.log('[READ]', 'OK', file);
                            resolve(new that.File(file, content));
                        }

                    });

                }
            });

        }


        if (isCache) {
            this.fileCache[file] = ret;
        }


        return ret;
    },



    /*
     * 转换到绝对路径，支持 HTTP 形式
     * @param   {String}    来源路径
     * @param   {String}    子路径
     * @return  {String}    绝对路径
     */
    resolve: function (from, to) {

        if (RE_SERVER.test(from)) {
            return url.resolve(from, to);
        } else if (RE_SERVER.test(to)) {
            return to;
        } else {
            return path.resolve(from, to);
        }
    },



    /*
     * 标准化路径
     * @param   {String}    路径
     * @return  {String}    标准化路径
     */
    normalize: function (src) {

        // ../font/font.eot?#font-spider
        var RE_QUERY = /[#?].*$/g;

        if (RE_SERVER.test(src)) {
            return src;
        } else {
            src = src.replace(RE_QUERY, '');
            return path.normalize(src); 
        }
    },


    /*
     * 解析 HTML 
     * @param   {String}            文件绝对路径
     * @return  {}
     */
    htmlParser: function (htmlFile) {


        //htmlFile = path.resolve(htmlFile);
        
        var $;
        var that = this;
        
        
        var base = path.dirname(htmlFile);


        return this.getFile(htmlFile)


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

                if (!that.filter([href]).length) {

                    return;
                }
                

                // link 标签
                if (href) {

                    

                    cssFile = that.resolve(base, href);
                    cssFile = that.map(cssFile);
                    cssFile = that.normalize(cssFile);

                    cssContent = that.getFile(cssFile, htmlFile);
                    


                // style 标签
                } else {
                    cssContent = new that.File(htmlFile, $this.text());
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
                var cssInfo = that.cssParser(cssContent, cssFile);
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

                    if (!that.fontsCache[family]) { // TODO 这一句可能因为顺序问题产生BUG
                        return;
                    }

                    that.charsCache[family] = that.charsCache[family] || '';

                    // 剔除状态伪类
                    rules = rules.replace(RE_SPURIOUS, '');

                    try {
                        var elements = $(rules);
                    } catch (e) {
                        // 1. 包含 :before 等不支持的伪类
                        // 2. 非法语句
                        return;
                    }

                    that.log('[%s]', family, rules);
                    
                    elements.each(function (index, element) {

                        // 找到使用了字体的文本
                        that.charsCache[family] += $(element).text();

                    });
                });


            };


            cssInfos.forEach(function (cssInfo) {

                cssInfo.fonts.forEach(function (item) {
                    that.fontsCache[item.name] = item.files;
                });

                // 提取 HTML 的文本
                cssInfo.selectors.forEach(eachSelectors);

                //that.log('[CSS]', JSON.stringify(cssInfo, null, 4));

            });


        });
        
    },

    getOptions: function (options) {
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
    map: function (src) {
        var regs = this.options.map;

        if (!regs || !regs.length) {
            return src;
        }

        if (!Array.isArray(regs[0])) {
            regs = [regs];
        }

        regs.forEach(function (reg) {
            src = src.replace.apply(src, reg);
        });

        return src;
    },



    // 筛选路径
    filter: function (srcs) {
        return this.ignore.filter(srcs);
    },



    // 提取 css 中要用到的信息
    cssParser: function (string, filename) {

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
        var cache = this.cssParserCache[filename];
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

            
            var err = [];

            if (e.line !== undefined) {
                err.push(e.toString());
            } else if (e.stack) {
                err.push(e.stack);
            }

            err.push('Source: ' + filename);

            that.error(err.join('\n'));

            return {
                fonts: [],
                selectors: []
            };
        }


        var parser = function (rule) {

            var position = rule.position;

            switch (rule.type) {

                case 'import':
                    
                    
                    var src = rule['import'];
                    

                    // @import url("./g.css?t=2009");
                    // @import "./g.css?t=2009";
                    if (RE_URL.test(src)) {
                        RE_URL.lastIndex = 0;
                        src = RE_URL.exec(src)[1];
                    }

                    src = src.replace(RE_QUOTATION, '');

                    if (!that.filter([src]).length) {
                        break;
                    }

                    

                    var target = that.resolve(base, src);
                    var line = position ? position.start.line : null;
                    
                    target = that.map(target);
                    target = that.normalize(target);

                    importInfo = that.getFile(target, filename, line)
                    .then(function (data) {
                        var cssContent = data.content;
                        var cssInfo = that.cssParser(cssContent, target);
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
                                var src;

                                RE_URL.lastIndex = 0;
                                while ((src = RE_URL.exec(value)) !== null) {

                                    src = src[1];
                                    src = src.replace(RE_QUOTATION, '');
                                    
                                    src = that.resolve(base, src);
                                    src = that.map(src);
                                    src = that.normalize(src);

                                    if (family.files.indexOf(src) === -1) {
                                        family.files.push(src);
                                    }
                                }

                                break;
                        }
                    });


                    if (family.name) {
                        family.files = that.filter(family.files);
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


        return this.cssParserCache[filename] = importInfo || {
            fonts: fonts,
            selectors: selectors
        };
    },


    info: function () {
        console.info.apply(console, arguments);
    },


    error: function () {
        if (!this.options.silent || this.options.debug) {
            console.error.apply(console, arguments);
        }
    },


    log: function () {
        if (this.options.debug) {
            console.log.apply(console, arguments);
        }
    }
};


module.exports = Spider;


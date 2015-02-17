'use strict';

var fs = require('fs');
var path = require('path');
var css = require('css');
var ignore = require('ignore');
var cheerio = require('cheerio');
var Promise = require('promise');

var readFile = Promise.denodeify(fs.readFile);
var writeFile = Promise.denodeify(fs.writeFile);
var exists = function (uri) {
    return new Promise(function (resolve, reject) {
        fs.exists(uri, function (exists) {
            resolve(exists);
        });
    });
};


// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;

// ../font/font.eot?#font-spider
var RE_QUERY = /[#?].*$/g;


var Spider = function (htmlFiles, options, callback) {

    options = this._getOptions(options);


    if (typeof htmlFiles === 'string') {
        htmlFiles = [htmlFiles];
    }

    var promiseList = [];
    var that = this;

    this._debug = options.debug;


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

    Promise.all(promiseList)
    .then(function (contents) {

        var result = that._getResult();
        //that._log('result', result);

        callback(null, result);

    }, function (errors) {

    })

    .then(null, function (errors) {
        console.error(errors)
    });


};


Spider.defaults = {
    debug: false,
    silent: false,
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
     * @return   {Spider.prototype._File, Promise}       文件对象
     */
    _getFile: function (file, sourceFile, sourceLine) {
        var that = this;
        var cache = this._fileCache[file];


        if (cache) {

            return cache;

        } else if (RE_SERVER.test(file)) {

            if (sourceLine) {
                that._error('Error: ' + sourceFile + ':' + sourceLine);
            }

            that._error('Error: does not support the absolute path "' + file + '"\n');
            this._fileCache[file] = new that._File(file, content);

        } else {

            this._fileCache[file] = exists(file)
            .then(function (exists) {
                if (exists) {
                    return readFile(file, 'utf8')
                    .then(function (content) {
                        return new that._File(file, content);
                    });
                } else {
                    that._error('Error: not found "' + file + '"\n');
                    return new that._File(file, '');
                }
            });
        }

        return this._fileCache[file];
    },



    /*
     * 解析 HTML 
     * @param   {String}            文件绝对路径
     * @return  {}
     */
    _htmlParser: function (htmlFile) {


        htmlFile = path.resolve(htmlFile)
        this._log('[HTML] document.URL', htmlFile);
        
        var $;
        var that = this;
        
        
        var htmlDir = path.dirname(htmlFile);


        return this._getFile(htmlFile)


        // 查找页面中的样式内容
        // 如 link 标签与页面内联 style 标签

        .then(function (data) {
            
            var htmlContent = data.content;
            $ = cheerio.load(htmlContent);

            var styleSheets = $('link[rel=stylesheet], style');
            var cssContents = [];

            // 查询页面中所有样式表
            styleSheets.each(function (index, element) {

                //that._log('[HTML]', $(element).outerHTML.replace(/>[\w\W]*<\//, '> ... <\/'));

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
                    href = href.replace(RE_QUERY, ''); 

                    cssFile = path.resolve(htmlDir, href);

                    cssContent = that._getFile(cssFile);
                    


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

                    if (!that._fontsCache[family]) {
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

                that._log('[CSS]', JSON.stringify(cssInfo, null, 4));

            });


        })

        .then(null, function (errors) {
            console.error(errors && errors.stack || errors);
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


    // 数组除重复
    _unique: function (array) {
        var ret = [];

        array.forEach(function (val) {
            if (ret.indexOf(val) === -1) {
                ret.push(val);
            }
        });

        return ret;
    },


    _getResult: function () {

        var list = [];
        var files = this._fontsCache;
        var chars = this._charsCache;
        var that = this;


        
        Object.keys(chars).forEach(function (familyName) {
            // 对文本进行除重操作
            chars[familyName] = that._unique(chars[familyName].split('')).join('');
            // 删除无效字符
            chars[familyName] = chars[familyName].replace(/[\n\r\t]/g, '');
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
        
        return list;
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

        filename = filename.replace(RE_QUERY, '');


        var that = this;
        var cache = this._cssParserCache;
        var base = path.dirname(filename);
        var importInfo = null;


        if (cache[filename]) {
            return cache[filename];
        }

        // 字体文件信息
        var fonts = [];

        // 选择器信息
        var selectors = [];

        try {
            var ast = css.parse(string);
        } catch (e) {

            that._error('Error: ' + filename);
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
                    url = url.replace(RE_QUERY, '');

                    var target = path.resolve(base, url);
                    var line = position ? position.start.line : null;
                    
                    importInfo = that._getFile(target, url, line)
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
                                    url = url.replace(RE_QUERY, '');

                                    if (!RE_SERVER.test(url)) {

                                        url = path.resolve(base, url);

                                        if (family.files.indexOf(url) === -1) {
                                            family.files.push(url);
                                        }

                                    } else {

                                        var errorInfo = filename;
                                        
                                        if (position) {
                                            errorInfo += (':' + position.start.line);
                                        }

                                        that._error('Error: ' + errorInfo);
                                        that._error('Error: does not support the absolute path "' + url + '"\n');

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


        return cache[filename] = importInfo || {
            fonts: fonts,
            selectors: selectors
        };
    },

    _error: function () {
        if (!this.options.silent || this._debug) {
            console.error.apply(console, arguments);
        }
    },

    _log: function () {
        if (this._debug) {
            console.log.apply(console, arguments);
        }
    }
};


module.exports = Spider;


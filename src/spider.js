'use strict';

var fs = require('fs');
var path = require('path');
var http = require('http');
var url = require('url');
var css = require('css');
var ignore = require('ignore');
var cheerio = require('cheerio');
var Promise = require('promise');
var ColorConsole = require('./color-console.js');


// http://font-spider.org/css/style.css
//var RE_SERVER = /^(\/|http\:|https\:)/i;
var RE_SERVER = /^(http\:|https\:)/i;


var getCssError = function (error) {
    return error.toString().replace(/^Error:\s*/, '');
};


var Spider = function (htmlFiles, options, callback) {

    options = this._getOptions(options);
    callback = callback || function () {};


    if (typeof htmlFiles === 'string') {
        htmlFiles = [htmlFiles];
    }

    new ColorConsole(options).mix(this);

    
    var that = this;


    this.fontsCache = {};
    this.charsCache = {};
    this.fileCache = {};
    this.cssParserCache = {};

    this.options = options;


    this.ignore = ignore({
        ignore: options.ignore
    });


    htmlFiles = this.filter(htmlFiles)
    .map(function (htmlFile) {
        return that.htmlParser(htmlFile);
    });


    return Promise.all(htmlFiles)
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
    sort: true,         // 是否将查询到的文本按字体中字符的顺序排列
    unique: true,       // 是否去除重复字符
    ignore: [],         // 忽略的文件配置
    map: [],            // 文件映射配置
    log: false,         // 是否显示调试日志
    info: true,         // 是否显示提示
    error: true,        // 是否显示错误
    warn: true          // 是否显示警告
};







Spider.prototype = {

    constructor: Spider,


    /*
     * 解析 HTML 
     * @param   {String}            文件绝对路径
     * @return  {Promise}
     */
    htmlParser: function (htmlFile) {

        
        var $;
        var that = this;
        
        
        var base = path.dirname(htmlFile);


        return this.resource({
            file: htmlFile,
            from: 'Node',
            cache: false
        })


        // 查找页面中的样式内容
        // 如 link 标签与页面内联 style 标签

        .then(function (resource) {
            
            var htmlContent = resource.content;
            var resources = [];

            $ = cheerio.load(htmlContent);


            // TODO base 标签顺序影响
            base = $('base[href]').attr('href') || base;


            // 外部样式
            $('link[rel=stylesheet]').each(function (index) {

                var line = index + 1;
                var $this = $(this);
                var cssFile;
                var href = $this.attr('href');


                // 忽略含有有 disabled 属性的
                if ($this.attr('disabled') && $this.attr('disabled') !== 'false') {
                    return;
                }

                if (!that.filter([href]).length) {
                    return;
                }



                cssFile = that._resolve(base, href);
                cssFile = that.map(cssFile);
                cssFile = that._normalize(cssFile);

                resources.push(that.resource({
                    file: cssFile,
                    from: htmlFile + '#<link:nth-of-type(' + line + ')>',
                    base: path.dirname(cssFile),
                    cache: true
                }));

            });



            // 页面内联样式
            $('style').each(function (index) {

                var line = index + 1;
                var $this = $(this);
                // 忽略含有有 disabled 属性的
                if ($this.attr('disabled') && $this.attr('disabled') !== 'false') {
                    return;
                }

                resources.push(that.resource({
                    file: htmlFile + '#<style:nth-of-type(' + line + ')>',
                    from: htmlFile,
                    base: base,
                    cache: false,
                    content: $this.text()
                }));

            });
            

            return Promise.all(resources);
        })
    

        // 解析样式表

        .then(function (resources) {

            var cssInfos = [];

            resources.forEach(function (resource) {
                var cssInfo = that.cssParser(resource);
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

                that.log(JSON.stringify(cssInfo, null, 4));

            });


        });
        
    },




    // 提取 css 中要用到的信息
    cssParser: function (resource) {

        var string = resource.content;
        var file = resource.file;
        var from = resource.from;
        var base = resource.base;

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
        var cache = this.cssParserCache[file];
        
        var imports = [];


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

            

            if (e.line !== undefined) {
                that.error('[ERROR]', getCssError(e),
                    '\n     ', 'file:', file);
            } else if (e.stack) {
                that.error('[ERROR]',
                    '\n     ', 'file:', file, e.stack);
            }

            return {
                fonts: [],
                selectors: [],
                from: from
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

                    

                    var target = that._resolve(base, src);
                    var line = position ? position.start.line : null;
                    
                    target = that.map(target);
                    target = that._normalize(target);

                    // TODO 超过一层嵌套后，from 不准确
                    imports.push(
                        that.resource({
                            file: target,
                            base: path.dirname(target),
                            from: file,
                            line: line,
                            cache: true
                        })
                        .then(function (resource) {
                            return that.cssParser(resource);
                        })
                    );

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
                                    
                                    src = that._resolve(base, src);
                                    src = that.map(src);
                                    src = that._normalize(src);

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


        imports.unshift({
            fonts: fonts,
            selectors: selectors,
            from: from
        });


        return this.cssParserCache[file] = Promise.all(imports)
        .then(function (res) {
            var cssInfo = {
                fonts: [],
                selectors: [],
                from: from
            };

            res.forEach(function (item) {
                cssInfo.fonts = cssInfo.fonts.concat(item.fonts);
                cssInfo.selectors = cssInfo.selectors.concat(item.selectors);
            });

            return cssInfo;
        });
    },




    /*
     * 资源。注意：读取错误的文件会返回空字符串，不会进入错误流程
     * @param   {Object options}          <options.file>, ...
     * @param   {Promise, options}        <options.file>, <options.content>, ...
     */
    resource: function (options) {

        var file = options.file;
        var content = options.content;
        var isCache = options.cache !== undefined;

        if (content !== undefined) {
            return options;
        } else {
            options.content = '';
        }

        var from = options.from;

        var that = this;
        
        var cache = this.fileCache[file];
        var ret;


        if (cache) {

            return cache;
        
        }

        var error = function (errors) {
            var fromCode = from;

            if (typeof options.line !== undefined) {
                fromCode == from + ':' + options.line;
            }

            that.error('[ERROR]', 'load "' + file + '" failed',
                '\n     ', 'from:', fromCode);
        };

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
                        var buffer = Buffer.concat(chunks, size);

                        options.content = buffer.toString();

                        that.info('Load', '<' + file + '>');
                        resolve(options);
                    });

                })
                .on('error', function (errors) {

                    error(errors);

                    resolve(options);
                });


            // 本地文件
            } else {

                fs.readFile(file, 'utf8', function (errors, content) {

                    if (errors) {

                        error(errors);

                        resolve(options);
                    } else {

                        options.content = content;
                        that.log('[SUCCEED]', '<read>', file);
                        resolve(options);
                    }

                });

            }
        });

        


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
    _resolve: function (from, to) {

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
    _normalize: function (src) {

        // ../font/font.eot?#font-spider
        var RE_QUERY = /[#?].*$/g;

        if (RE_SERVER.test(src)) {
            return src;
        } else {
            src = src.replace(RE_QUERY, '');
            return path.normalize(src); 
        }
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
    }

};


module.exports = Spider;


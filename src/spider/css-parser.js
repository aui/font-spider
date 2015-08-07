/* global require,module,console */

'use strict';

var path = require('path');
var crypto = require('crypto');
var utils = require('./utils');
var CSSOM = require('cssom');
var Resource = require('./resource');
var Promise = require('./promise');
var VError = require('verror');



function CssParser (resource /*,importLength*/) {

    var importLength = arguments[1] || 0;


    if (resource instanceof Promise) {
        return resource.then(function (resource) {
            return new CssParser(resource, importLength);
        });
    }


    if (!(resource instanceof Resource.Model)) {
        throw new Error('require `Resource.Model`');
    }


    return new Promise(function (resolve, reject) {

        var file = resource.file;
        var content = resource.content;
        var options = resource.options;
        var cache = options.cache;
        var ast, tasks;


        if (cache) {
            tasks = CssParser.cache[file];
            if (tasks) {
                // 深拷贝缓存
                return resolve(utils.copy(tasks));
            }
        }


        content = getContent(content);

        try {
            ast = CSSOM.parse(content);
        } catch (errors) {
            
            return reject(
                new VError(errors, 'parse "%s" failed', file)
            );
        }


        tasks = new CssParser
        .Parser(ast, file, options, importLength);


        Promise.all(tasks)
        .then(function (tasks) {
            var cssInfo = [];
            tasks.forEach(function (item) {
                if (Array.isArray(item)) {
                    cssInfo = cssInfo.concat(item);
                } else if (item instanceof CssParser.Model) {
                    cssInfo.push(item);
                }
            });


            if (cache) {
                CssParser.cache[file] = cssInfo;
            }


            if (options.debug) {
                console.log('');
                console.log('[DEBUG]', 'CssParser', file);
                console.log(cssInfo);
            }

            resolve(cssInfo);

        })
        .catch(reject);

        
    });
}





CssParser.Model = function CssInfo (type) {

    // {String} 类型：CSSFontFaceRule | CSSStyleRule
    this.type = type;

    // {String, Array} 字体 ID
    this.id = null;

    // {String, Array} 字体名
    this.family = null;

    // {String} 字体绝对路径
    this.files = null;

    // {Array} 使用了改字体的选择器信息
    this.selectors = null;

    // {Array} 字体使用的字符（包括 content 属性）
    this.chars = null;

    // {Object} 字体相关选项 @see getFontId.keys
    this.options = null;

};

CssParser.Model.prototype.mix = function (object) {
    utils.mix(this, object);
    return this;
};





CssParser.cache = {};



/*
 * 默认选项
 */
CssParser.defaults = {
    cache: true,            // 缓存开关
    debug: false,           // 调试开关
    maxImportCss: 16,       // CSS @import 语法导入的文件数量限制
    ignore: [],             // 忽略的文件配置
    map: []                 // 文件映射配置
};





CssParser.Parser = function (ast, file, options, importLength) {

    options = utils.options(CssParser.defaults, options);

    var that = this;
    var tasks = [];

    this.options = options;
    this.base = path.dirname(file);
    this.file = file;
    this.importLength = importLength;

    this.ignore = utils.ignore(options.ignore);
    this.map = utils.map(options.map);


    ast.cssRules.forEach(function (rule) {
        var type = rule.constructor.name;
        var cssInfo;

        if (typeof that[type] === 'function') {

            cssInfo = that[type](rule);
            if (cssInfo) {
                tasks.push(cssInfo);
            }
        }
    });

    return tasks;
};





CssParser.Parser.prototype = {

    constructor: CssParser.Parser,


    // CSS 导入规则
    // @import url("fineprint.css") print;
    // @import url("bluish.css") projection, tv;
    // @import 'custom.css';
    // @import url("chrome://communicator/skin/");
    // @import "common.css" screen, projection;
    // @import url('landscape.css') screen and (orientation:landscape);
    CSSImportRule: function (rule) {

        var that = this;
        var base = this.base;
        var options = this.options;
        
        var url = utils.unquotation(rule.href.trim());
        url = utils.resolve(base, url);
        url = this._getUrl(url);


        if (!url) {
            return;
        }


        this.importLength ++;   

        // 限制导入的样式数量，避免让爬虫进入死循环陷阱
        if (this.importLength > options.maxImportCss) {
            var errors = new Error('the number of files imported exceeds the maximum limit');
            errors = new VError(errors, 'parse "%s" failed', that.file);
            return Promise.reject(errors);
        }


        var resource = new Resource(url, null, options)
        .catch(function (errors) {
            errors = new VError(errors, 'parse "%s" failed', that.file);
            return Promise.reject(errors);
        });


        return new CssParser(resource, this.importLength);
    },


    // webfont 规则
    // @see https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face
    CSSFontFaceRule: function (rule) {
        var base = this.base;
        var files = [];
        var style = rule.style;
        var that = this;

        var model = new CssParser
        .Model('CSSFontFaceRule')
        .mix({
            id: '',
            family: '',
            files: files,
            selectors: [],
            chars: [],
            options: {}
        });

        
        // 解析 font 相关属性
        Array.prototype.forEach.call(style, function (key) {

            if (key === 'font-family') {

                model.family = utils.unquotation(style['font-family']);

            } else if (key === 'font') {

                model.options = utils.fontValueParse(style.font) || {};
                model.family = model.options['font-family'];

                if (Array.isArray(model.family)) {
                    model.family = model.family[0];
                }

                delete model.options['font-family'];

            } else if (getFontId.keys.indexOf(key) !== -1) {

                model.options[key] = style[key];
            } 
        });



        if (!model.family) {
            return;
        }


        model.id = getFontId(model.family, model.options);

        
        // 解析字体地址
        var src = utils.srcValueParse(style.src);
        var urls = [];
        src.forEach(function (file) {
            file = utils.resolve(base, file);
            file = that._getUrl(file);
            if (file) {
                urls.push(file);
            }
        });

        files.push.apply(files, urls);

        return model;
    },


    // 选择器规则
    CSSStyleRule: function (rule) {

        var style = rule.style;
        
        if (!style['font-family'] && !style.font) {
            return;
        }


        var selectorText = rule.selectorText;
        var content = style.content || '';
        
        // CSS content 属性
        // @see https://developer.mozilla.org/en-US/docs/Web/CSS/content
        if (/^['"]|['"]$/.test(content)) {
            content = utils.unquotation(content);
        } else if (/^(?:open|close)-quote$/.test(content)) {

            console.warn('[WARN]', 'does not support `content: ' + content + '`',
                'from:', this.file,
                'selector:', selectorText);

        }
        

        var model = new CssParser
        .Model('CSSStyleRule')
        .mix({
            id: [],
            family: [],
            files: [],
            // TODO [data-name="ss,ss"]
            // /((?:[^,"']|"[^"]*"|'[^']*')+)/
            selectors: utils.commaToArray(selectorText),
            chars: content.split(''),
            options: {}
        });


        // 解析 font 相关属性
        Array.prototype.forEach.call(style, function (key) {

            if (key === 'font-family') {

                model.family = utils
                .commaToArray(style['font-family'])
                .map(utils.unquotation);

            } else if (key === 'font') {

                model.options = utils.fontValueParse(style.font) || {};
                model.family = model.options['font-family'];
                delete model.options['font-family'];

            } else if (getFontId.keys.indexOf(key) !== -1) {

                model.options[key] = style[key];
            } 
        });


        if (!model.family || !model.family.length) {
            return;
        }


        // 生成匹配的字体 ID 列表
        model.family.forEach(function (family) {
            var id = getFontId(family, model.options);
            model.id.push(id);
        });


        // 不支持继承的字体
        if (model.family.indexOf('inherit') !== -1) {
            console.warn('[WARN]', 'does not support `font-family: inherit`',
                'from:', this.file,
                'selector:', selectorText);
        }


        return model;
    },


    // 媒体查询规则
    CSSMediaRule: function (rule) {
        return new CssParser.Parser(
            rule,
            this.file,
            this.options,
            this.importLength
        );
    },


    // 转换文件地址
    // 执行顺序：ignore > map > normalize
    _getUrl: function (file) {
        if (!this.ignore(file)) {
            file = this.map(file);
            file = utils.normalize(file);
            return file;
        }
    }

};






// 用来给字体指定唯一标识
// 字体的 ID 根据 font-family 以及其他 font-* 属性来生成
// @see https://github.com/aui/font-spider/issues/32
function getFontId (name, options) {

    var values = getFontId.keys.map(function (key, index) {

        var value = options[key] || getFontId.values[index];

        if (typeof value !== 'string') {
            value = getFontId.values[index];
        } else if (getFontId.alias[key]) {
            value = value.replace.apply(value, getFontId.alias[key]);
        }

        return value;
    });

    values.unshift(name);

    var id = values.join('-');
    id = crypto.createHash('md5').update(id).digest('hex');

    return id;
}


getFontId.keys = ['font-variant', 'font-stretch', 'font-weight', 'font-style'];
getFontId.values = ['normal', 'normal', 'normal', 'normal'];
getFontId.alias = {
    'font-weight': ['400', 'normal'],
};



function getContent (content) {
    // 去掉 @charset，因为它可能触发 cssom 库的 bug
    // 使用空格占位避免改动代码位置
    return content.replace(/^(\@charset\b.+?;)(.*?)/i, function ($0, $1, $2) {
        return Array($1.length).join(' ') + $2
    });
}




module.exports = CssParser;

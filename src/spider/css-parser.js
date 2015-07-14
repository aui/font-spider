/* global require,module */

'use strict';

var path = require('path');
var utils = require('./utils');
var logUtil = require('./log-util');
var CSSOM = require('cssom');
var Resource = require('./resource');
var Promise = require('./promise');


function CssParser (resource) {

    if (resource instanceof Promise) {
        return resource.then(function (resource) {
            return new CssParser(resource);
        });
    }


    if (!(resource instanceof Resource.Content)) {
        throw new Error('require `Resource.Content`');
    }


    var file = resource.file;
    var content = resource.content;
    var options = resource.options;
    var cache = options.cache;
    var cssParser;


    options.base = options.base || path.dirname(file);


    if (cache) {
        cssParser = CssParser.cache[file];
        if (cssParser) {
            return cssParser;
        }
    }

    var ast;

    try {
        ast = CSSOM.parse(content);
    } catch (error) {
        return logUtil.error(error);
    }

    cssParser = new CssParser.Parser(ast, options);

    if (cache) {
        CssParser.cache[file] = cssParser;
    }

    return cssParser;
}

CssParser.Model = function (type) {
    this.type = type;
    this.mix(CssParser.Model.defaults);
};

CssParser.Model.defaults = {
    // unicode-range TODO
    'font-variant': 'normal',
    'font-stretch': 'normal',
    'font-weight': 'normal',
    'font-style': 'normal'
};

CssParser.Model.defaultsKeys = Object.keys(CssParser.Model.defaults);
CssParser.Model.prototype.mix = function (object) {
    utils.mix(this, object);
    return this;
};


CssParser.cache = {};



CssParser.Parser = function Parser (ast, options) {
    var that = this;
    var tasks = [];

    this.options = options;
    this.base = options.base;


    // 忽略文件
    this.filter = utils.filter(options.ignore);

    // 对文件地址进行映射
    this.map = utils.map(options.map);


    ast.cssRules.forEach(function (rule) {
        var type = rule.constructor.name;
        var ret;

        if (typeof that[type] === 'function') {

            try {
                ret = that[type](rule);
            } catch (e) {
                // debug
                console.error(type, e.stack);
            }

            if (ret) {
                tasks.push(ret);
            }
        }
    });


    var promise = Promise.all(tasks)
    .then(function (list) {
        
        var ret = [];
        list.forEach(function (item) {
            if (Array.isArray(item)) {
                ret = ret.concat(item);
            } else if (item instanceof CssParser.Model) {
                ret.push(item);
            }
        });

        return ret;
    });


    return promise;
};



utils.mix(CssParser.Parser.prototype, {


    // CSS 导入规则
    // @import url("fineprint.css") print;
    // @import url("bluish.css") projection, tv;
    // @import 'custom.css';
    // @import url("chrome://communicator/skin/");
    // @import "common.css" screen, projection;
    // @import url('landscape.css') screen and (orientation:landscape);
    CSSImportRule: function (rule) {

        var base = this.base;
        var file = utils.unquotation(rule.href.trim());

        logUtil.log('@import', file);

        file = utils.resolve(base, file);
        file = this.filter(file);
        file = this.map(file);
        file = utils.normalize(file);

        if (!file) {
            return;
        }

        var options = {
            base: path.dirname(file)
        };


        return new CssParser(new Resource(file, null, options));
    },


    // webfont 规则
    // @see https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face
    CSSFontFaceRule: function (rule) {
        var base = this.base;
        var files = [];
        var family = utils.unquotation(rule.style['font-family']);
        var extname = '';

        logUtil.log('@font-face', family);

        var model = new CssParser.Model('CSSFontFaceRule').mix({
            id: '@' + family,
            family: family,
            files: files,
            selectors: [],
            chars: []
        });


        // 复制 font 相关规则
        CssParser.Model.defaultsKeys.forEach(function (key) {
            var value = rule.style[key];
            if (typeof value === 'string') {
                model[key] = value;
            }

            extname += model[key];
        });

        model.id += extname;

        
        var urls = utils.urlToArray(rule.style.src);
        urls = urls.map(function (file) {
            file = utils.resolve(base, file);
            return utils.normalize(file);
        });

        urls = this.filter(urls);
        urls = this.map(urls);

        files.push.apply(files, urls);

        return model;
    },


    // 选择器规则
    CSSStyleRule: function (rule) {

        var selectorText = rule.selectorText;
        var fontFamily = rule.style['font-family'];
        var content = utils.unquotation(rule.style.content || '');
        var ids = [];
        var extname = '';

        if (!fontFamily) {
            return;
        }

        // 将字体拆分成数组
        var familys = utils.commaToArray(fontFamily).map(utils.unquotation);
        var model = new CssParser.Model('CSSStyleRule').mix({
            ids: ids,
            selectors: utils.commaToArray(selectorText),
            familys: familys,
            chars: content.split('')
        });


        // 复制 font 相关规则
        CssParser.Model.defaultsKeys.forEach(function (key) {
            var value = rule.style[key];
            if (typeof value === 'string') {
                model[key] = value;
            }

            extname += model[key];
        });


        // 生成对应的字体 ID 列表
        familys.forEach(function (family) {
            ids.push('@' + family + extname);
        });



        return model;
    },


    // 媒体查询规则
    CSSMediaRule: function (rule) {
        return new this.constructor(rule, this.options);
    }

});


module.exports = CssParser;

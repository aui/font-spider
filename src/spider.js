'use strict';

var fs = require('fs');
var path = require('path');
var async = require('async');
var css = require('css');
var jsdom = require('./jsdom');

var RE_SERVER = /^(http\:|https\:)/;

var Spider = function (htmlFiles, callback, debug) {

	if (typeof htmlFiles === 'string') {
		htmlFiles = [htmlFiles];
	}

	this._htmlFiles = htmlFiles;
	this._debug = !!debug;
	this._files = {};
	this._chars = {};
	this._selectors = {};
	this._cssFiles = {};

	this._load(callback);
};

Spider.prototype = {

	constructor: Spider,

	_load: function (callback) {

		var that = this;

		var htmlFiles = this._htmlFiles;

		if (typeof htmlFiles === 'string') {
			htmlFiles = [htmlFiles];
		}

		async.each(htmlFiles, function (htmlFile, callback) {

			htmlFile = path.resolve(htmlFile);

			jsdom.env({
				file: htmlFile,
				done: function (errors, window) {
					if (errors) {
						throw errors;
					}


					that._htmlParser(htmlFile, window);
					window.close();

					callback();
				}
			});
			
		}, function (errors) {

			if (errors) {
				throw errors;
			}

			var result = that._getResult();
			that._log('result', result);

			callback(result);
		});
	},



	_getResult: function () {

		var familyName;
		var list = [];
		var hashmap;
		var files = this._files;
		var chars = this._chars;
		var selectors = this._selectors;
		var fn = function (val) {
			if (hashmap[val]) {
				return false;
			} else {
				hashmap[val] = true;
				return true;
			}
		};

		// 对文本进行除重操作
		for (familyName in chars) {
			hashmap = {};
			chars[familyName] = chars[familyName].split('').filter(fn).join('');
			hashmap = null;
		}


		for (familyName in files) {
			if (chars[familyName]) {
				list.push({
					name: familyName,
					chars: chars[familyName],
					selectors: selectors[familyName].join(', '),
					files: files[familyName]
				});
			}
		}

		
		return list;
	},


	// 在 DOM 环境中提取信息
	_htmlParser: function (htmlFile, window) {

		var document = window.document;

		this._log('[HTML] document.URL', document.URL);
		
		var that = this;
		var htmlDir = path.dirname(htmlFile);
		var styleSheets = document.querySelectorAll('link[rel=stylesheet], style');
		var RE_SPURIOUS = /\:(link|visited|hover|active|focus)\b/ig;

		var setCharsCache = function (data) {

			var cssSelectors = data.selectors.join(', ');
			data.familys.forEach(function (family) {

				that._chars[family] = that._chars[family] || '';
				that._selectors[family] = that._selectors[family] || [];

				// 剔除状态伪类
				var selectors = cssSelectors.replace(RE_SPURIOUS, '');

				var elements = document.querySelectorAll(selectors);

				that._selectors[family].push(selectors);

				elements = Array.prototype.slice.call(elements);
				elements.forEach(function (element) {

					// 找到使用了字体的文本
					that._chars[family] += element.textContent;

				});
			});


		};


		// 查询页面中所有样式表
		styleSheets = Array.prototype.slice.call(styleSheets);
		styleSheets.forEach(function (elem) {

			that._log('[HTML]', elem.outerHTML.replace(/>[\w\W]*<\//, '> ... <\/'));

			var cssInfo;
			var cssContent;
			var cssDir = htmlDir;
			var cssFile;

			// 忽略含有有 disabled 属性的
			if (elem.disabled) {
				return;
			}

			// link 标签
			if (elem.href) {
				
				if (!RE_SERVER.test(elem.href)) {
					cssFile = path.resolve(htmlDir, elem.href);
					cssDir = path.dirname(cssFile);

					if (!that._cssFiles[cssFile]) {
						cssContent = fs.readFileSync(cssFile, 'utf-8');
					}
				} else {
					that._log('[CSS] ignore', elem.href);
				}


			// style 标签
			} else {
				cssContent = elem.textContent;
			}


			if (cssFile && that._cssFiles[cssFile]) {
				cssInfo = that._cssFiles[cssFile];
			} else {

				// 根据 css 选择器查询使用了自定义字体的节点
				cssInfo = that._cssParser(cssContent, cssDir);
				cssInfo.files.forEach(function (data, cssFile) {
					that._files[data.name] = data.files;
					data.files.forEach(function (value, index) {
						data.files[index] = path.resolve(cssDir, value);
					});
				});

				// 记录已处理过的样式文件
				cssFile && (that._cssFiles[cssFile] = cssInfo);
			}

			// 提取 HTML 的文本
			cssInfo.selectors.forEach(setCharsCache);

			that._log('[CSS]', JSON.stringify(cssInfo, null, 4));

		});

	},


	// 提取 css 中要用到的信息
	_cssParser: function (string, base) {

		var that = this;
		var files = [];
		var selectors = [];

		var RE_URL = /url\(['"]?(.*?)['"]?\)/ig;
		var RE_SPLIT = /[#?].*$/g;
		var RE_QUOTATION = /^['"]|['"]$/g;
		var RE_SPLIT_COMMA = /\s*,\s*/;

		var ast = css.parse(string, {});

		var parser = function (rule) {

			switch (rule.type) {

				case 'import':
					
					RE_URL.lastIndex = 0;
					var url = RE_URL.exec(rule['import'])[1];

					if (!RE_SERVER.test(url)) {
						var target = path.resolve(base, url);
						var cssContent = fs.readFileSync(target, 'utf-8');
						var cssInfo = that._cssParser(cssContent, path.dirname(target));

						files = files.concat(cssInfo.files);
						selectors = selectors.concat(cssInfo.selectors);
					}

					break;

				case 'font-face':

					var family = {
						name: '',
						files: []
					};

					rule.declarations.forEach(function (declaration) {

						var property = declaration.property;
						var value = declaration.value;

						switch (property) {
							case 'font-family':

								value = value.trim().replace(RE_QUOTATION, '');

								family.name = value;
								
								break;

							case 'src':
								var url;

								RE_URL.lastIndex = 0;
								while ((url = RE_URL.exec(value)) !== null) {
									url = url[1].replace(RE_SPLIT, '');
									if (!RE_SERVER.test(url)) {
										family.files.push(url);
									}
								}

								break;
						}
					});

					files.push(family);

					break;

				case 'media':

					rule.rules.forEach(parser);
					break;

				case 'rule':

					var selector = {
						selectors: rule.selectors,// 注意：包含伪类选择器
						familys: [],
						content: ''
					};


					rule.declarations.forEach(function (declaration) {

						var property = declaration.property;
						var value = declaration.value;

						switch (property) {
							case 'font-family':

								value.split(RE_SPLIT_COMMA).forEach(function (val) {
									// 去掉空格与前后引号
									val = val.trim().replace(RE_QUOTATION, '');
									selector.familys.push(val);
								});
								
								break;

							case 'content':
								// 忽略这里
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


		return {
			files: files,
			selectors: selectors
		};
	},

	_log: function () {
		if (this._debug) {
			console.log.apply(console, arguments);
		}
	}
};


module.exports = Spider;

// TODO: 测试大写 css 规则
'use strict';

var fs = require('fs');
var path = require('path');
var async = require('async');
var css = require('css');
var jsdom = require('./jsdom');

// http://font-spider.org/css/style.css
var RE_SERVER = /^(\/|http\:|https\:)/i;

// ../font/font.eot?#font-spider
var RE_QUERY = /[#?].*$/g;


var Spider = function (htmlFiles, callback, debug) {

	if (typeof htmlFiles === 'string') {
		htmlFiles = [htmlFiles];
	}

	this._htmlFiles = htmlFiles;
	this._debug = !!debug;
	this._files = {};
	this._chars = {};
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

		async.each(htmlFiles, function (htmlFile, cb) {

			htmlFile = path.resolve(htmlFile);

			jsdom.env({
				file: htmlFile,
				done: function (errors, window) {
					if (errors) {
						throw errors;
					}


					that._htmlParser(htmlFile, window);
					window.close();

					cb();
				}
			});
			
		}, function (errors) {

			var result = errors ? null : that._getResult();
			that._log('result', result);

			callback(errors, result);
		});
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
		var files = this._files;
		var chars = this._chars;
		var that = this;


		// 对文本进行除重操作
		Object.keys(chars).forEach(function (familyName) {
			chars[familyName] = that._unique(chars[familyName].split('')).join('');
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

				if (!that._files[family]) {
					return;
				}

				that._chars[family] = that._chars[family] || '';

				// 剔除状态伪类
				var selectors = cssSelectors.replace(RE_SPURIOUS, '');

				try {
					var elements = document.querySelectorAll(selectors);
				} catch (e) {
					// 1. 包含 :before 等不支持的伪类
					// 2. 非法语句
					return;
				}
				

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
			var cssDir = htmlDir;
			var cssFile;
			var href = elem.getAttribute('href');
			var cssContent = '';

			// 忽略含有有 disabled 属性的
			if (elem.disabled) {
				return;
			}

			// link 标签
			if (href) {

				href = href.replace(RE_QUERY, '');
				
				if (!RE_SERVER.test(href)) {

					cssFile = path.resolve(htmlDir, href);
					cssDir = path.dirname(cssFile);

					if (!that._cssFiles[cssFile] && fs.existsSync(cssFile)) {
						cssContent = fs.readFileSync(cssFile, 'utf-8');
					}
				} else {
					that._log('[CSS] ignore', href);
				}


			// style 标签
			} else {
				cssContent = elem.textContent;

			}


			if (cssFile && that._cssFiles[cssFile]) {
				cssInfo = that._cssFiles[cssFile];
			} else {

				// 根据 css 选择器查询使用了自定义字体的节点
				cssInfo = that._cssParser(cssContent, cssFile || htmlFile);

				cssInfo.files.forEach(function (data, cssFile) {

					that._files[data.name] = data.files;

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
	_cssParser: function (string, filename) {

		// url(../font/font.ttf)
		var RE_URL = /url\(['"]?(.*?)['"]?\)/ig;

		// "../font/font.ttf"
		var RE_QUOTATION = /^['"]|['"]/g;

		// !important
		var RE_IMPORTANT = /!important[\s\t]*$/i;

		// art, lanting, heiti
		var RE_SPLIT_COMMA = /\s*,\s*/;

		filename = filename.replace(RE_QUERY, '');

		var that = this;
		var base = path.dirname(filename);
		var files = [];
		var selectors = [];

		try {
			var ast = css.parse(string, {
				//silent: true
			});
		} catch (e) {

			if (e.line !== undefined) {
				console.error(filename);
				console.error(e.toString());
			} else {
				throw e;
			}

			return {
				files: [],
				selectors: []
			};
		}


		var parser = function (rule) {

			switch (rule.type) {

				case 'import':
					
					RE_URL.lastIndex = 0;
					var url = RE_URL.exec(rule['import'])[1];
					url = url.replace(RE_QUERY, '');

					if (!RE_SERVER.test(url)) {
						var target = path.resolve(base, url);

						if (fs.existsSync(target)) {
							var cssContent = fs.readFileSync(target, 'utf-8');
							var cssInfo = that._cssParser(cssContent, target);

							files = files.concat(cssInfo.files);
							selectors = selectors.concat(cssInfo.selectors);
						}

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
									url = url[1].replace(RE_QUERY, '');
									if (!RE_SERVER.test(url)) {

										url = path.resolve(base, url);

										if (family.files.indexOf(url) === -1) {
											family.files.push(url);
										}

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

// TODO:
// 异步优化
// 测试大写 css 规则
// html base 标签处理
// 支持远程资源
// css hack 语法处理
// 错误流程优化
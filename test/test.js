var assert = require("assert");
var path = require('path');

var Spider = require('../src/spider/index');
var utils = require('../src/spider/utils');
var Resource = require('../src/spider/resource');
var CssParser = require('../src/spider/css-parser');
var HtmlParser = require('../src/spider/html-parser');

// TODO 大小写路径测试


describe('Utils', function () {

    describe('#unquotation', function () {
        it('双引号', function () {
            assert.equal('hello world', utils.unquotation('"hello world"'));
        });
        it('单引号', function () {
            assert.equal('hello world', utils.unquotation('\'hello world\''));
        });
    });


    describe('#mix', function () {
        var target = {
            test: 9
        };

        var object = {
            a: 4,
            test: 0
        };

        utils.mix(target, object);

        it('混合', function () {
            assert.equal(object.test, target.test);
            assert.equal(object.a, target.a);
            assert.equal(4, target.a);
        });
    });


    describe('#unique', function () {
        it('类型一致', function () {
            var list = [9, 0, 2, 3, 9, 5, 4, 5, 2, 2, 1];
            var ret = utils.unique(list).sort(function (a, b) {
                return a - b;
            }).join(',');
            assert.equal('0,1,2,3,4,5,9', ret);
        });

        it('类型不一致', function () {
            var list = [1, '1', 0, '0', 2, 2, 3];
            var ret = utils.unique(list);
            assert.equal(6, ret.length);
        });
    });


    describe('#srcValueParse', function () {

        it('单个地址', function () {
            var list = utils.srcValueParse('url(MgOpenModernaBold.ttf)');
            assert.equal('MgOpenModernaBold.ttf', list[0]);
        });

        it('多个地址', function () {
            var list = utils.srcValueParse('local("Helvetica Neue Bold"), url(MgOpenModernaBold.ttf), url("2.otf"), url( \'x.woff\' )');
            assert.equal('MgOpenModernaBold.ttf', list[0]);
            assert.equal('2.otf', list[1]);
            assert.equal('x.woff', list[2]);
        });

    });


    describe('#commaToArray', function () {

        it('单个字体', function () {
            var list = utils.commaToArray('aui');
            assert.equal('aui', list[0]);
        });

        it('多个字体', function () {
            var list = utils.commaToArray(' aaa, \'bbb\', "ccc",   ddd, fff ');
            assert.equal('aaa', list[0]);
            assert.equal('\'bbb\'', list[1]);
            assert.equal('"ccc"', list[2]);
            assert.equal('ddd', list[3]);
            assert.equal('fff', list[4]);
        });

    });


    describe('#resolve', function () {

        it('本地路径', function () {
            var file = utils.resolve('/User/doc', '../test.css');
            assert.equal('/User/test.css', file);
        });

        it('本地路径2', function () {
            var file = utils.resolve('/User/doc', './test.css');
            assert.equal('/User/doc/test.css', file);
        });

        it('本地路径3', function () {
            var file = utils.resolve('/User/doc', 'test.css');
            assert.equal('/User/doc/test.css', file);
        });

        it('本地路径4', function () {
            var file = utils.resolve('/User/doc/', 'test.css');
            assert.equal('/User/doc/test.css', file);
        });

        it('本地路径5', function () {
            var file = utils.resolve('/User/doc/', '../test.css');
            assert.equal('/User/test.css', file);
        });

        it('远程路径', function () {
            var file = utils.resolve('http://qq.com/User/doc', '../test.css');
            assert.equal('http://qq.com/User/test.css', file);
        });

        it('远程路径2', function () {
            var file = utils.resolve('http://qq.com/User/doc', 'http://font-spider.org/test.css');
            assert.equal('http://font-spider.org/test.css', file);
        });

        it('远程路径3', function () {
            var file = utils.resolve('http://qq.com/User/doc', 'test.css');
            assert.equal('http://qq.com/User/doc/test.css', file);
        });

        it('远程路径4', function () {
            var file = utils.resolve('http://qq.com/User/doc/', 'test.css');
            assert.equal('http://qq.com/User/doc/test.css', file);
        });

        it('远程路径5', function () {
            var file = utils.resolve('http://qq.com/User/doc', './test.css');
            assert.equal('http://qq.com/User/doc/test.css', file);
        });

    });


    describe('#dirname', function () {

        it('远程目录', function () {
            var file = utils.dirname('http://font-spider.org');
            assert.equal('http://font-spider.org', file);
        });

        it('远程目录2', function () {
            var file = utils.dirname('http://font-spider.org/');
            assert.equal('http://font-spider.org', file);
        });

        it('远程目录3', function () {
            var file = utils.dirname('http://font-spider.org/t.html');
            assert.equal('http://font-spider.org', file);
        });

    });


    describe('#normalize', function () {

        it('标准化路径', function () {
            var file = utils.normalize('../font.eot?1245442#iefix#');
            assert.equal('../font.eot', file);
        });

        it('标准化路径2', function () {
            var file = utils.normalize('http://font-spider.org/font.eot?1245442#iefix#');
            assert.equal('http://font-spider.org/font.eot?1245442', file);
        });

        it('标准化路径3', function () {
            var file = utils.normalize('http://font-spider.org/font.eot?#iefix#');
            assert.equal('http://font-spider.org/font.eot', file);
        });
    });


    describe('#isRemoteFile', function () {
        it('判断是否为远程地址', function () {
            assert.equal(true, utils.isRemoteFile('http://www.baidu.com/test.css'));
            assert.equal(true, utils.isRemoteFile('https://www.baidu.com/test.css'));
            assert.equal(false, utils.isRemoteFile('./test.css'));
            assert.equal(false, utils.isRemoteFile('/test.css'));
            assert.equal(false, utils.isRemoteFile('/temp/test.css?#iefix'));
            assert.equal(false, utils.isRemoteFile('./temp/test.css?#iefix'));
        });
    });


    describe('#reduce', function () {
        it('数组扁平化', function () {
            assert.equal(7, utils.reduce([[0, 1, 2, 3], [5, 6, 3]]).length);
        });
    });


    describe('#map', function () {
        it('字符串', function () {
            var map = utils.map([
                ['http://font-spider.org/css/', '/User/aui/css/']
            ]);
            assert.equal('/User/aui/css/inc/test.css', map('http://font-spider.org/css/inc/test.css'));
        });

        it('字符串2', function () {
            var map = utils.map([]);
            assert.equal('http://font-spider.org/css/inc/test.css', map('http://font-spider.org/css/inc/test.css'));
        });

        it('函数', function () {
            var map = utils.map(function (file) {
                return file.replace('http://font-spider.org/css/', '/User/aui/css/');
            });

            assert.equal('/User/aui/css/inc/test.css', map('http://font-spider.org/css/inc/test.css'));
        });
    });

    describe('#ignore', function () {
        it('字符串', function () {
            var ignore = utils.ignore([
                '*.eot',
                'icon.css'
            ]);
            assert.equal(true, ignore('test.eot'));
            assert.equal(false, ignore('test.ttf'));
        });

        it('字符串2', function () {
            var ignore = utils.ignore([]);
            assert.equal(false, ignore('test.eot'));
        });

        it('函数', function () {
            var ignore = utils.ignore(function (file) {
                return /.*\.eot|icon.css/.test(file);
            });
            assert.equal(true, ignore('test.eot'));
            assert.equal(false, ignore('test.ttf'));
        });
    });

});



describe('Resource', function(){
    describe('#Resource(file)', function(){
        it('读取本地文件', function (done) {
            new Resource(__dirname + '/css/test.css')
            .then(function (resource) {
                var error = resource.content.indexOf('/*@test*/') !== 0;
                if (error) {
                    done(error);
                } else {
                    done();
                }
            }, function (error) {
                done(error);
            });
        });

        it('测试错误处理：读取不存在的本地文件', function (done) {
            new Resource(__dirname + '/css/xxxxxxxxxx.css')
            .then(function (resource) {
                done(resource);
            }, function (error) {
                done();
            });
        });

        it('读取远程文件', function (done) {
            new Resource('http://www.baidu.com')
            .then(function (resource) {
                done();
            }, function (error) {
                done(error);
            });
        });

        // it('测试错误处理：读取不存在的远程文件', function (done) {
        //     new Resource('http://www.twitter.com/fsdfsdfdsfdsf/')
        //     .then(function (resource) {
        //         done(resource);
        //     }, function (error) {
        //         done();
        //     });
        // });

    });

    describe('#Resource(file, content)', function(){
        it('设置内容', function () {
            new Resource('#test', 'hello world')
            .then(function (resource) {
                assert.equal('#test', resource.file);
                assert.equal('hello world', resource.content);
                done();
            }, function (error) {
                done(error);
            });
        });
    });

    describe('#Resource(file, content, options)', function(){
        it('设置内容', function () {
            new Resource('#test', 'hello world', {test: true})
            .then(function (resource) {
                assert.equal('#test', resource.file);
                assert.equal('hello world', resource.content);
                assert.equal(true, resource.options.test);
                done();
            }, function (error) {
                done(error);
            });
        });
    });
});




describe('CssParser', function () {

    describe('#@import', function(){

        it('basic', function (done) {
            new Resource(__dirname + '/css/test.css')
            .then(function (resource) {
                new CssParser(resource).then(function (list) {
                    var item = list[0];
                    if (!item || !Array.isArray(item.files)) {
                        done('没有按预期格式返回');
                        return;
                    } else {
                        done();
                    }
                }, function (error) {
                    done(error);
                });
            }, function (error) {
                done(error);
            });
        });
        

        it("@import 'test.css';", function (done) {
            new Resource('TEMP/temp.css', '@import \'' +  __dirname + '/css/test.css\';')
            .then(function (resource) {
                new CssParser(resource).then(function (list) {
                    var item = list[0];
                    if (!item || !Array.isArray(item.files)) {
                        done('没有按预期格式返回');
                        return;
                    } else {
                        done();
                    }
                }, function (error) {
                    done(error);
                });
            }, function (error) {
                done(error);
            });
        });


        it('@import url("test.css") projection, tv;', function (done) {
            new Resource('TEMP/temp.css', '@import url("' + __dirname + '/css/test.css") projection, tv;')
            .then(function (resource) {
                new CssParser(resource).then(function (list) {
                    var item = list[0];
                    if (!item || !Array.isArray(item.files)) {
                        done('没有按预期格式返回');
                        return;
                    } else {
                        done();
                    }
                }, function (error) {
                    done(error);
                });
            }, function (error) {
                done(error);
            });
        });

        it('@import url("test.css") screen and (orientation:landscape);', function (done) {
            new Resource('TEMP/temp.css', '@import url("' + __dirname +'/css/test.css") screen and (orientation:landscape);')
            .then(function (resource) {
                new CssParser(resource).then(function (list) {
                    var item = list[0];
                    if (!item || !Array.isArray(item.files)) {
                        done('没有按预期格式返回');
                        return;
                    } else {
                        done();
                    }
                }, function (error) {
                    done(error);
                });
            }, function (error) {
                done(error);
            });
        });

        it('@import url("chrome://communicator/skin/");', function (done) {
            new Resource('TEMP/temp.css', '@import url("chrome://communicator/skin/");')
            .then(function (resource) {
                new CssParser(resource)
                .then(function (list) {
                    done('应该走入错误流程');
                }, function (error) {
                    done();
                });
            });
        });

    });


    describe('#@font-face', function () {
        it('单个', function (done) {
            new Resource(__dirname + '/css/font-face1.css')
            .then(function (resource) {
                var css = new CssParser(resource).then(function (list) {

                    var item = list[0];

                    if (!item || !Array.isArray(item.files)) {
                        return done('没有按预期格式返回');
                    }

                    if (item.type !== 'CSSFontFaceRule') {
                        return done('type error');
                    }

                    
                    var files = {};
                    files[__dirname + '/font/aui.eot'] = true;
                    files[__dirname + '/font/aui.ttf'] = true;
                    files[__dirname + '/font/aui.woff'] = true;
                    files[__dirname + '/font/aui.svg'] = true;
                    var some = item.files.some(function (file) {
                        return !files[file];
                    });


                    if (some) {
                        return done('字体路径解析错误');
                    }

                    if (item.family !== 'aui') {
                        return done('family error');
                    }

                    if (item.options['font-weight'] !== 'bold') {
                        return done('font-weight error');
                    }

                    if (item.options['font-style'] !== 'normal') {
                        return done('font-style error');
                    }

                    done();

                });
                
            }, function (error) {
                done(error);
            });
        });

        it('多个', function (done) {
            new Resource(__dirname + '/css/font-face2.css')
            .then(function (resource) {
                var css = new CssParser(resource).then(function (list) {

                    var item = list[0];

                    if (!item || !Array.isArray(item.files)) {
                        return done('没有按预期格式返回');
                    }

                    if (item.type !== 'CSSFontFaceRule') {
                        return done('type error');
                    }

                    
                    var files = {};
                    files[__dirname + '/font/aui.eot'] = true;
                    files[__dirname + '/font/aui.ttf'] = true;
                    files[__dirname + '/font/aui.woff'] = true;
                    files[__dirname + '/font/aui.svg'] = true;
                    var some = item.files.some(function (file) {
                        return !files[file];
                    });


                    if (some) {
                        return done('#1 字体路径解析错误');
                    }

                    if (item.family !== 'aui') {
                        return done('#1 family error');
                    }

                    if (item.options['font-weight'] !== 'bold') {
                        return done('#1 font-weight error');
                    }


                    /////////////

                    item = list[1];
                    files = {};
                    files[__dirname + '/font/aui-normal.eot'] = true;
                    files[__dirname + '/font/aui-normal.ttf'] = true;
                    files[__dirname + '/font/aui-normal.woff'] = true;
                    files[__dirname + '/font/aui-normal.svg'] = true;
                    some = item.files.some(function (file) {
                        return !files[file];
                    });


                    if (some) {
                        return done('#2 字体路径解析错误');
                    }

                    if (item.family !== 'aui') {
                        return done('#2 family error');
                    }

                    if (item.options['font-weight'] !== 'normal') {
                        return done('#2 font-weight error');
                    }

                    /////////////
                    
                    item = list[2];
                    files = {};
                    files[__dirname + '/css/font/test.eot'] = true;
                    files[__dirname + '/css/font/test.ttf'] = true;
                    files[__dirname + '/css/font/test.woff'] = true;
                    files[__dirname + '/css/font/test.svg'] = true;
                    some = item.files.some(function (file) {
                        return !files[file];
                    });


                    if (some) {
                        return done('#3 字体路径解析错误');
                    }

                    if (item.family !== 'test') {
                        return done('#3 family error');
                    }

                    if (item.options['font-weight'] !== 'normal') {
                        return done('#3 font-weight error');
                    }

                    done();

                });
                
            }, function (error) {
                done(error);
            });
        });
    });


    describe('#font', function () {

        it('缩写', function () {
            new CssParser(new Resource('TEMP/temp.css', ".test {font:italic bold 12px/20px arial,'sans-serif';}"))
            .then(function (cssInfo) {
                cssInfo.forEach(function (rule) {
                    if (rule.type === 'CSSStyleRule' && rule.selector.indexOf('.test') === 0) {
                        if (
                            rule.family.indexOf('arial') !== -1
                            && rule.family.indexOf('sans-serif') !== -1
                            && rule.options['font-weight'] === 'bold'
                            && rule.options['font-style'] === 'italic') {
                            done();
                        } else {
                            done(rule);
                        }
                    } else {
                        done(rule);
                    }
                });

            });
        });

    });

    
    describe('#error', function () {
        it('死循环', function (done) {

            new CssParser(new Resource(__dirname + '/css/loop.css')).then(null, function (errors) {
                done();
            });

        });
    });

});



describe('HtmlParser', function () {

    describe('#getCssFiles', function () {
        it('getCssFiles()', function (done) {

            new HtmlParser(new Resource(__dirname + '/html/index.html'))
            .then(function (htmlParser) {
                var cssFiles = htmlParser.getCssFiles();
                var indexOf = cssFiles.indexOf(__dirname + '/css/background.css');

                if (cssFiles.length !== 1) {
                    done(cssFiles.length);
                } else if (indexOf === -1) {
                    done(indexOf);
                } else {
                    done()
                } 
            });

 
        });
    });



    describe('#getCssFiles', function () {



        it('getCssContents()', function (done) {

            new HtmlParser(new Resource(__dirname + '/html/index.html'))
            .then(function (htmlParser) {
                var cssContents = htmlParser.getCssContents();
                var indexOf = cssContents[0].indexOf('aui');
                
                if (cssContents.length !== 3) {
                    done(cssContents.length);
                } else if (indexOf === -1) {
                    done(indexOf);
                } else {
                    done();
                }
            }, function (error) {
                done(error);
            });

        });

    });


    describe('#querySelectorChars', function () {

        it('querySelectorChars(selector)', function (done) {
            var htmlParser = new HtmlParser(new Resource(__dirname + '/html/index.html'))
            .then(function (htmlParser) {
                var chars = htmlParser.querySelectorChars('#test ul li:last-child');
                var string = chars.join('');

                if (string === 'hello world') {
                    done();
                } else {
                    done(string);
                }
            }, function (error) {
                done(error);
            });
        });
        
    });


    describe('Spider', function () {

        describe('#Spider', function () {

            it('Spider', function (done) {
                new Spider([__dirname + '/html/test.html'])
                .then(function (data) {
                    //console.log(data);
                    done();
                }, function (error) {
                    done(error);
                });
            });

        });

    });

});

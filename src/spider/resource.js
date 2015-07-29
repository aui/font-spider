/* global require,Buffer,module */

// TODO 超时配置参数

'use strict';

var fs = require('fs');
var http = require('http');
var https = require('https');
var url = require('url');
var zlib = require('zlib');
var utils = require('./utils');
var Promise = require('./promise');
var VError = require('verror');




/*
 * 资源，支持远程路径与本地路径
 * @param   {String}    绝对路径
 * @param   {String}    内容。可选，如果为 String 则直接返回 Promise 对象  
 * @param   {Object}    选项。@see Resource.defaults 
 * @return  {Promise}
 */
function Resource (file, content, options) {

    options = utils.options(Resource.defaults, options);
    
    var resource;
    var data = new Resource.Model(file, content, options);

    var cache = options.cache;
    var resourceBeforeLoad = options.resourceBeforeLoad;
    var resourceLoad = options.resourceLoad;
    var resourceError = options.resourceError;
    
    resourceBeforeLoad(file);

    if (cache) {
        resource = Resource.cache[file];
        if (resource) {
            return resource.then(function (data) {

                // 深拷贝缓存
                data = new Resource.Model(
                    data.file,
                    data.content,
                    utils.copy(data.options)
                );

                resourceLoad(file, data);
                
                return data;
            }, function (errors) {
                resourceError(file, errors);
                return Promise.reject(errors);
            });
        }
    }


    if (typeof content === 'string') {
        return Promise.resolve(data);
    }


    resource = new Promise(function (resolve, reject) {

        // 远程文件
        if (utils.isRemoteFile(file)) {

            
            var location = url.parse(file);
            var protocol = location.protocol === 'http:' ? http : https;

            var request = protocol.request({
                method: 'GET',
                host: location.host,
                hostname: location.hostname,
                path: location.path,
                port: location.port,
                headers: {
                    'accept-encoding': 'gzip,deflate'
                }
            }, function (res) {

                var encoding = res.headers['content-encoding'];
                var type = res.headers['content-type'];
                var errors = null;


                if (res.statusCode !== 200) {
                    errors = new Error(res.statusMessage);
                } else if (type.indexOf('text/') !== 0) {
                    errors = new Error('only supports `text/*` resources');
                }


                if (errors) {
                    reject(errors);
                } else {

                    var buffer = new Buffer([]);


                    if (encoding === 'undefined') {
                        res.setEncoding('utf-8'); 
                    }


                    res.on('data', function (chunk) {
                        buffer = Buffer.concat([buffer, chunk]);
                    });

                    res.on('end', function () {                

                        if (encoding === 'gzip') {

                            zlib.unzip(buffer, function(errors, buffer) {
                                if (errors) {
                                    reject(errors);
                                } else {
                                    resolve(buffer.toString());
                                }
                            });

                        } else if (encoding == 'deflate') {

                            zlib.inflate(buffer, function (errors, decoded) {
                                if (errors) {
                                    reject(errors);
                                } else {
                                    resolve(decoded.toString());
                                }
                            });

                        } else {
                            resolve(buffer.toString());
                        }

                    });

                }

            })
            .on('error', reject);

            request.end();


        // 本地文件
        } else {

            
            fs.readFile(file, 'utf8', function (errors, content) {

                if (errors) {
                    reject(errors);
                } else {
                    resolve(content);
                }

            });

        }
    })
    .then(function (content) {
        data.content = content;
        resourceLoad(file, data);
        return data;
    })
    .catch(function (errors) {
        errors = new VError(errors, 'ENOENT, load "%s" failed', file);
        resourceError(file, errors);
        return Promise.reject(errors);
    });

    if (cache) {
        Resource.cache[file] = resource;
    }

    return resource;
}



/*
 * 缓存对象
 */
Resource.cache = {};




/*
 * 默认选项
 */
Resource.defaults = {
    cache: false,
    resourceLoad: function () {},
    resourceBeforeLoad: function () {},
    resourceError: function () {}
};




/*
 * 模型工厂
 * @param   {String}    文件地址
 * @param   {String}    文件内容
 * @param   {Object}    额外的数据
 * @return  {Object}    .file, .content, .options
 */
Resource.Model = function ResourceData (file, content, options) {
    this.file = file;
    this.content = content || '';
    this.options = options || {};
};




module.exports = Resource;
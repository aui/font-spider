/* global require,Buffer,module */

// TODO 超时配置参数

'use strict';

var fs = require('fs');
var http = require('http');
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

            var request = http.get(file, function (res) {

                if (res.statusCode !== 200) {

                    var errors = new Error(res.statusMessage);
                    errors = new VError(errors, 'ENOENT, load "%s" failed', file);

                    resourceError(file, errors);
                    reject(errors);
                    request.end();

                } else {

                    var size = 0;
                    var chunks = []; 

                    res.on('data', function (chunk) {
                        size += chunk.length;
                        chunks.push(chunk);
                    });

                    res.on('end', function () {

                        
                        
                        var buffer = Buffer.concat(chunks, size);
                        data.content = buffer.toString();
                        resourceLoad(file, data);

                        resolve(data);

                    });

                }

            })
            .on('error', function (errors) {
                errors = new VError(errors, 'ENOENT, load "%s" failed', file);
                resourceError(file, errors);
                reject(errors);
            });


        // 本地文件
        } else {

            
            fs.readFile(file, 'utf8', function (errors, content) {

                if (errors) {
                    resourceError(file, errors);
                    reject(errors);
                } else {
                    
                    data.content = content;
                    resourceLoad(file, data);
                    resolve(data);
                }

            });

        }
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
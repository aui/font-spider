/* global require,Buffer,module */

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
 * @param   {Object}    选项。options.cache, options.onload 
 * @return  {Promise}
 */
function Resource (file, content, options) {

    
    var data = new Resource.Model(file, content, options);
    var cache = data.options.cache;
    var onload = data.options.onload || function () {};
    var resource;


    if (cache) {
        resource = Resource.cache[file];
        if (resource) {
            return resource.then(function (data) {

                onload(file);

                // 深拷贝缓存
                return new Resource.Model(
                    data.file,
                    data.content,
                    utils.copy(data.options)
                );
            });
        }
    }


    if (typeof content === 'string') {
        return Promise.resolve(data);
    }


    resource = new Promise(function (resolve, reject) {

        

        // 远程文件
        if (utils.isRemote(file)) {

            var request = http.get(file, function (res) {

                if (res.statusCode !== 200) {

                    var errors = new Error(res.statusMessage);
                    errors = new VError(errors, 'ENOENT, load "%s" failed', file);

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

                        onload(file);
                        
                        var buffer = Buffer.concat(chunks, size);
                        data.content = buffer.toString();
                        
                        resolve(data);

                    });

                }

            })
            .on('error', function (errors) {
                errors = new VError(errors, 'ENOENT, load "%s" failed', file);
                reject(errors);
            });


        // 本地文件
        } else {

            
            fs.readFile(file, 'utf8', function (errors, content) {

                if (errors) {
                    reject(errors);
                } else {
                    onload(file);
                    data.content = content;
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

Resource.cache = {};

Resource.Model = function (file, content, options) {
    this.file = file;
    this.content = content || '';
    this.options = options || {};
};




module.exports = Resource;
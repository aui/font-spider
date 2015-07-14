/* global require,Buffer,module */

'use strict';

var fs = require('fs');
var http = require('http');
var utils = require('./utils');
var logUtil = require('./log-util');
var Promise = require('./promise');

/*
 * 资源，支持远程路径与本地路径
 * @param   {String}    路径
 * @param   {String}    内容。可选，如果为 String 则直接返回 Promise 对象  
 * @param   {Object}    选项。options.cache: 是否缓存
 * @return  {Promise}
 */
function Resource (file, content, options) {

    

    var data = new Resource.Content(file, content, options);
    var cache = data.options.cache;
    var resource;


    if (cache) {
        resource = Resource.cache[file];
        if (resource) {
            return resource;
        }
    }

    if (typeof content === 'string') {
        return Promise.resolve(data);
    }

    resource = new Promise(function (resolve, reject) {

        // 远程文件
        if (utils.isRemote(file)) {

            logUtil.info('load', file);

            http.get(file, function (res) {

                if (res.statusCode !== 200) {

                    var errors = new Error(res.statusMessage);

                    logUtil.error(errors);
                    reject(errors);

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
                        
                        resolve(data);
                    });

                }

            })
            .on('error', logUtil.error);


        // 本地文件
        } else {

            logUtil.log('load', file);
            fs.readFile(file, 'utf8', function (errors, content) {

                if (errors) {
                    logUtil.error(errors);
                    reject(errors);
                } else {

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

Resource.Content = function Content (file, content, options) {
    this.file = file;
    this.content = content || '';
    this.options = options || {};
};



module.exports = Resource;
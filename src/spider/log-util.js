/* global require,module */

'use strict';

var util = require('util');
var events = require('events');
var Promise = require('./promise');

var eventEmitter = new events.EventEmitter();

module.exports = {

    on: function () {
        eventEmitter.on.apply(eventEmitter, arguments);
    },

    log: function () {
        var args = ['log'];
        args.push.apply(args, arguments);
        eventEmitter.emit.apply(eventEmitter, args);
    },

    info: function () {
        var args = ['info'];
        args.push.apply(args, arguments);
        eventEmitter.emit.apply(eventEmitter, args);
    },

    warn: function () {
        var args = ['warn'];
        args.push.apply(args, arguments);
        eventEmitter.emit.apply(eventEmitter, args);
    },

    // @see http://code.oneapm.com/nodejs/2015/04/13/nodejs-errorhandling/?from=groupmessage&isappinstalled=0
    error: function (error) {
        var args = ['error'];
        args.push.apply(args, arguments);
        // 注意，如果没有默认 error 处理函数可能导致 Node 退出
        eventEmitter.emit.apply(eventEmitter, args);
        return Promise.reject(error);
    }
};




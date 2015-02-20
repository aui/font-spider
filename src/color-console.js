'use strict';

var STYLES = require('../src/color');

var TAGS = [
    // 成功
    [/^\<(.*?)\>$/, 'green'],
    // 错误
    [/^\{(.*?)\}$/, 'red'],
    // 醒目
    [/^\((.*?)\)$/, 'cyan'],
    // 特别醒目
    [/^\[(.*?)\]$/, 'inverse']
];


function setColor (name, string) {
    return STYLES[name][0] + string + STYLES[name][1];
};


function ColorConsole (options) {

    var that = this;
    var noop = function () {};

    Object.keys(this.config).forEach(function (key) {
        that[key] = options[key] ? function () {
            var config = that.config;
            var args = [].slice.call(arguments);
            var color = config[key];

            args = args.map(function (item, index) {

                if (typeof item !== 'object' || item === null) {

                    item = String(item);
                    TAGS.forEach(function (color) {
                        item = item.replace(color[0], function ($0, $1) {
                            return setColor(color[1], $1);
                        });
                    });

                    return color ? setColor(color, item) : item;
                } else {
                    return item;
                }

            });

            console[key].apply(console, args);

        } : noop;
    });
};

ColorConsole.prototype = Object.create(console);
ColorConsole.prototype.constructor = ColorConsole;
ColorConsole.prototype.config = {
    log: null,
    error: 'red',
    warn: 'yellow',
    info: null
};


ColorConsole.prototype.apply = function (context) {
    Object.keys(this).forEach(function (key) {
        context[key] = this[key];
    }.bind(this));
};



module.exports = ColorConsole;
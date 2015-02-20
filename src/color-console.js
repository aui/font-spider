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


var API = [
    ['log'],
    ['info'],
    ['error', 'red'],
    ['warn', 'yellow']
];


function setColor (name, string) {
    return STYLES[name][0] + string + STYLES[name][1];
};


function ColorConsole (options) {

    var that = this;
    var noop = function () {};

    API.forEach(function (item) {
        var key = item[0];
        var color = item[1];

        that[key] = options[key] ? function () {
            var args = [].slice.call(arguments);

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
ColorConsole.prototype.mix = function (context) {
    Object.keys(this).forEach(function (key) {
        context[key] = this[key];
    }.bind(this));
};



module.exports = ColorConsole;
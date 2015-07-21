/* global require,module */
'use strict';

var path = require('path');
var fs = require('fs');


function color (name, string) {
    var c = color.colors[name];
    if (c && typeof string === 'string') {
        return c[0] + string + c[1];
    } else {
        return string;
    }
}

color.colors = {
    // styles
    'bold'      : ['\x1B[1m',  '\x1B[22m'],
    'italic'    : ['\x1B[3m',  '\x1B[23m'],
    'underline' : ['\x1B[4m',  '\x1B[24m'],
    'inverse'   : ['\x1B[7m',  '\x1B[27m'],
    // colors
    'white'     : ['\x1B[37m', '\x1B[39m'],
    'grey'      : ['\x1B[90m', '\x1B[39m'],
    'black'     : ['\x1B[30m', '\x1B[39m'],
    'blue'      : ['\x1B[34m', '\x1B[39m'],
    'cyan'      : ['\x1B[36m', '\x1B[39m'],
    'green'     : ['\x1B[32m', '\x1B[39m'],
    'magenta'   : ['\x1B[35m', '\x1B[39m'],
    'red'       : ['\x1B[31m', '\x1B[39m'],
    'yellow'    : ['\x1B[33m', '\x1B[39m']
};


// 拷贝文件
function copyFile (srcpath, destpath) {
    var destdir = path.dirname(destpath);
    var contents = fs.readFileSync(srcpath);
    mkdir(destdir);
    fs.writeFileSync(destpath, contents);
}


// 重命名文件或文件夹
function rename (src, target) {
    if (fs.existsSync(src)) {
        var dir = path.dirname(target);
        mkdir(dir);
        fs.renameSync(src, target);
    }
}


// 创建目录，包括子文件夹
function mkdir (dir) {

    var currPath = dir;
    var toMakeUpPath = [];

    while (!fs.existsSync(currPath)) {
        toMakeUpPath.unshift(currPath);
        currPath = path.dirname(currPath);
    }

    toMakeUpPath.forEach(function (pathItem) {
        fs.mkdirSync(pathItem);
    });
}


// 删除文件夹，包括子文件夹
function rmdir (dir) {

    var walk = function (dir) {

        if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
            return;
        }

        var files = fs.readdirSync(dir);

        if (!files.length) {
            fs.rmdirSync(dir);
            return;
        } else {
            files.forEach(function (file) {
                var fullName = path.join(dir, file);
                if (fs.statSync(fullName).isDirectory()) {
                    walk(fullName);
                } else {
                    fs.unlinkSync(fullName);
                }
            });
        }

        fs.rmdirSync(dir);
    };

    walk(dir);
}



module.exports = {
    color: color,
    copyFile: copyFile,
    rename: rename,
    mkdir: mkdir,
    rmdir: rmdir
};
/* global require,module */
'use strict';

var path = require('path');
var fs = require('fs');



// 拷贝文件
function cp (srcpath, destpath) {
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
    cp: cp,
    rename: rename,
    mkdir: mkdir,
    rmdir: rmdir
};
'use strict';

var fs = require('fs');
var path = require('path');
var util = require('util');
var shell = require('shelljs');

// 检测 Perl 是否安装成功
var isPerl = shell.exec('perl -v', {silent: true}).code === 0;

var Optimizer = function (ttfFile) {

    // if (path.extname(ttfFile).toLocaleLowerCase() !== '.ttf') {
    //     throw "Only accept .ttf file";
    // }

    this._ttf = ttfFile;
};

Optimizer.COMMAND_NOT_FOUND = 127;

Optimizer.prototype.minify = function (dest, chars) {

    var src = this._ttf;

    // 如果 src === dest，生成的字体格式会损坏
    // 使用临时文件来解决此问题
    var temp = dest + '.ttf.__temp';

    // Windows 对中文编码支持有问题
    // 使用临时文件来解决此问题
    var charsfile = dest + '.txt.__temp';
    fs.writeFileSync(charsfile, chars, 'utf8');

    // Features to include.
    // - Use "none" to include no features.
    // - Leave array empty to include all features.
    // See list of all features:
    // http://en.wikipedia.org/wiki/OpenType_feature_tag_list#OpenType_typographic_features
    var includeFeatures = ['kern'];


    // Save old path so we can cwd back into it
    var oldCwd = path.resolve(".");
    shell.cd(path.join(__dirname, "./font-optimizer/"));

    // build execution command
    var cmd = [];
    cmd.push("perl -X ./subset.pl"); // Main executable
    // Included characters
    cmd.push(util.format('--charsfile=%s', JSON.stringify(charsfile)));
    if (includeFeatures.length !== 0) {
        // Included font features
        cmd.push("--include=" + includeFeatures.join(","));
    }
    cmd.push(JSON.stringify(src));
    cmd.push(JSON.stringify(temp));
    cmd = cmd.join(" ");
    
    var result = shell.exec(cmd, {silent: true});

    if (result.code !== 0) {
        // Error

        if (!isPerl) {
            result.code = Optimizer.COMMAND_NOT_FOUND;
        }
        
    } else {

        // subset.pl doesn't always fail completely, for example on
        // fsType 4 error. So we'll assume these errors are just
        // warnings and let the user decide what to do.

        // result.output

        if (fs.existsSync(temp)) {
            fs.renameSync(temp, dest);
        } else {
            console.error('error', result.output);
        }
        
    }

    fs.unlinkSync(charsfile);

    shell.cd(oldCwd);

    return result;
};

module.exports = Optimizer;

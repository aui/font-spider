'use strict';

var gulp = require('gulp');

gulp.task('clearup', function() {
    gulp.src('test/demo/**/*')
        .pipe(gulp.dest('test/demo-release'));
});
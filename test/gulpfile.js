'use strict';

var gulp = require('gulp');

gulp.task('default', function() {
    return gulp.src('demo/**/*')
        .pipe(gulp.dest('demo-release'));
});
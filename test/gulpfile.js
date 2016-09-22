'use strict';

var gulp = require('gulp');

gulp.task('release', function() {
    gulp.src('demo/**/*')
        .pipe(gulp.dest('demo-release'));
});
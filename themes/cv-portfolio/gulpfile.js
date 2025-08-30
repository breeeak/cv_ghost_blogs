const { src, dest, series } = require('gulp');
const concat = require('gulp-concat');
const cleanCSS = require('gulp-clean-css');
const terser = require('gulp-terser');

function styles(){
  return src('assets/css/**/*.css')
    .pipe(concat('style.css'))
    .pipe(cleanCSS())
    .pipe(dest('assets/built/'));
}

function scripts(){
  return src('assets/js/**/*.js')
    .pipe(concat('main.js'))
    .pipe(terser())
    .pipe(dest('assets/built/'));
}

exports.build = series(styles, scripts);


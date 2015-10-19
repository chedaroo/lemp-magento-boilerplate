"use strict";

// Include Gulp
var gulp = require('gulp');

// Include plugins
var $ = require('gulp-load-plugins')({
  pattern: ['gulp-*', 'del', 'browser-sync', 'main-bower-files', 'yargs'],
  rename: {
    'gulp-util' : 'gutil',
    'gulp-if'   : 'iff'
  }
});

// Set Environment flags
var isProduction = !!$.yargs.argv.production,
    isDev = !isProduction;

// Set Options
var options = {
  env : isProduction ? 'prod' : 'dev',
  jsDir : 'js',
  srcJsDir : 'src_js',
  cssDir : 'css',
  sassDir : 'scss',
  bowerDir : 'bower_components',
  parentThemeScssDir : '../../../../../www/skin/frontend/rwd/default/scss',
  log: function(title) {
    return function() {
      $.gutil.log($.gutil.colors.yellow('[' + title + ']'));
    };
  },
  successHandler: function(title) {
    return function() {
      $.gutil.log($.gutil.colors.green('[' + title + ']'));
    };
  },
  errorHandler: function(title) {
    return function(err) {
      $.gutil.log($.gutil.colors.red('[' + title + ']'), err.toString());
      this.emit('end');
    };
  }
}

// Helper function wrappers gulp-filter
var filterByExtension = function(extension){
    return $.filter(function(file){
        return file.path.match(new RegExp('.' + extension + '$'));
    });
};

// Install frontend dependencies from bower.json
gulp.task('bower', function() {
  return gulp.src(['bower.json'])
    .on('end', options.log('Installing Bower dependencies'))
    .pipe($.install())
    .on('error', options.errorHandler('Bower'));
});

// Compile SCSS
gulp.task('sass', function() {

  var scssFilter = $.filter('**/*.scss');

  var sassOptions = {
    outputStyle: 'expanded',
    includePaths: [options.parentThemeScssDir, options.bowerDir]
  };

  return gulp.src(options.sassDir + "/**/*.scss")
      .pipe($.iff(isDev, $.sourcemaps.init()))
      .pipe($.sass(sassOptions))
        .on('error', options.errorHandler('Sass'))
      .pipe($.iff(isProduction, $.minifyCss()))
      .pipe($.iff(isProduction, $.autoprefixer()))
      .pipe($.iff(isDev, $.sourcemaps.write()))
      .pipe(gulp.dest(options.cssDir))
      .pipe($.iff(isDev, $.browserSync.stream()));
});

// Scripts
gulp.task('scripts', function() {
  return gulp.src([options.srcJsDir + '/**/*.js'])
    .pipe(gulp.dest(options.jsDir));
});

// Uglify
gulp.task('uglify', function() {
  return gulp.src([options.srcJsDir + '/**/*.js'])
    .pipe($.uglify())
    .pipe(gulp.dest(options.jsDir));
});

// lint JS
gulp.task('lint', function() {
  return gulp.src([options.srcJsDir + '/**/*.js'])
    .pipe($.jshint())
    .pipe($.jshint.reporter('default'));
});

// Watch for changes
gulp.task('watch', function() {
  $.browserSync.init({
      proxy: "fsordersonline.magento.local",
      port: 3001
  });
  gulp.watch(options.srcJsDir + '/app.js', ['lint', 'scripts']);
  gulp.watch(options.sassDir + '/**/*.scss', ['sass']);
})

// Cleanup task - ensures files which have been renamed are removed
gulp.task('clean', function() {
  $.del([options.cssDir]);
});

gulp.task('dev', ['lint', 'sass', 'watch']);
gulp.task('production', ['sass', 'uglify']);
gulp.task('build', ['clean', 'bower'], function(){
    isProduction ? gulp.start('production') : gulp.start('dev');
});
gulp.task('default', ['clean'], function () {
    isProduction ? gulp.start('production') : gulp.start('dev');
});


/* -*- Mode: javascript; indent-tabs-mode: nil; js-indent-level: 2; -*- */

// Load Grunt
module.exports = function(grunt) {
  var js_files = {
    'js/pfappserver.js': ['app/application.js', 'admin/common.js'],
    'js/reports.js': ['admin/reports.js', 'admin/dynamicreport.js'],
    'js/auditing.js': ['admin/auditing.js', 'admin/radiusauditlog.js', 'admin/radiuslog.js', 'admin/option82.js'],
    'js/configuration.js': ['admin/configuration.js', 'admin/config/*.js']
  };
  var js_files_vendor_custom = {
    'js/vendor/bootstrap.min.js': [
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-transition.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-affix.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-alert.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-button.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-carousel.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-collapse.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-dropdown.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-modal.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-scrollspy.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-tab.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-tooltip.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-popover.js',
      'bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-typeahead.js',
      'bower_components/bootstrap-datepicker/js/bootstrap-datepicker.js',
      'bower_components/bootstrap-switch/src/js/bootstrap-switch.js',
      'app/bootstrap-timepicker.js',
      'app/jquery.ba-hashchange.js',
      'bower_components/chosen/chosen.jquery.js'
    ],
    'js/vendor/jquery-ui.min.js': [
      'bower_components/jquery-ui/ui/data.js',
      'bower_components/jquery-ui/ui/version.js',
      'bower_components/jquery-ui/ui/plugin.js',
      'bower_components/jquery-ui/ui/safe-active-element.js',
      'bower_components/jquery-ui/ui/safe-blur.js',
      'bower_components/jquery-ui/ui/scroll-parent.js',
      'bower_components/jquery-ui/ui/unique-id.js',
      'bower_components/jquery-ui/ui/widget.js',
      'bower_components/jquery-ui/ui/widgets/mouse.js',
      'bower_components/jquery-ui/ui/widgets/draggable.js',
      'bower_components/jquery-ui/ui/widgets/droppable.js'
    ],
    'js/vendor/jquery-extra.min.js': [
      'js/jquery.browser.js',
      'js/jquery.loader.js',
      'app/uri.js',
      'bower_components/clipboard/dist/clipboard.js',
    ]
  };
  var js_files_vendor_custom_minified = {
    'js/vendor/raphael.min.js': [
      'bower_components/raphael/raphael.min.js',
      'app/raphael/g.raphael-min.js',
      'app/raphael/g.bar-min.js',
      'app/raphael/g.dot-min.js',
      'app/raphael/g.line-min.js',
      'app/raphael/g.pie-min.js'
    ],
    'js/vendor/fitty.min.js': [
      'node_modules/fitty/dist/fitty.min.js'
    ]
  };
  var sass_include_paths = [
    'scss/',
    'bower_components/bootstrap-sass/vendor/assets/stylesheets/',
    'bower_components/font-awesome/scss/',
    'bower_components/sass-mq/'
  ];
  var css_vendor = [
    'app/bootstrap-timepicker.css'
  ];
  var css_vendor_minified = [
    'bower_components/bootstrap-switch/build/css/bootstrap2/bootstrap-switch.css',
    'bower_components/bootstrap-datepicker/dist/css/bootstrap-datepicker.min.css'
  ];

  require('time-grunt')(grunt);

  // Tasks
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    sass: {
      options: {
        sourceMap: true,
        outFile: 'css/styles.css',
        noCache: true,
        includePaths: sass_include_paths
      },
      target: {
        files: {
          'css/styles.css': ['scss/styles.scss']
        },
      },
    },
    postcss: {
      target: {
        options: {
          map: false,
          processors: [
            require('autoprefixer')({
              browsers: [
                "Android 2.3",
                "Android >= 4",
                "Chrome >= 20",
                "Firefox >= 24",
                "Explorer >= 8",
                "iOS >= 6",
                "Opera >= 12",
                "Safari >= 6"
              ]       
            })
          ]
        },
        src: 'css/styles.css'
      }
    },
    cssmin: {
      options: {
        sourceMap: true,
      },
      target: {
        files: {
          'css/styles.css': 'css/styles.css'
        }
      }
    },
    jshint: {
      files: [].concat(Object.keys(js_files).map(function(v) { return js_files[v]; }))
    },
    uglify: {
      options: {
        sourceMap: true
      },
      dist: {
        options: {
          compress: true,
          sourceMapIncludeSources: true
        },
        files: js_files
      },
      dev: {
        options: {
          compress: false,
          mangle: false,
        },
        files: js_files
      },
      vendor: {
        options: {
          compress: true,
        },
        files: js_files_vendor_custom
      },
      vendor_nocompress: {
        options: {
          compress: true,
        },
        files: js_files_vendor_custom_minified
      }
    },
    concat: {
      // Join CSS files not yet minified
      premin: {
        src: ['css/styles.css'].concat(css_vendor),
        dest: 'css/styles.css'
      },
      // Join minified CSS files
      postmin: {
        src: ['css/styles.css'].concat(css_vendor_minified),
        dest: 'css/styles.css'
      }
    }
  });

  // Load Grunt plugins
  grunt.loadNpmTasks('grunt-sass');
  grunt.loadNpmTasks('grunt-postcss');
  grunt.loadNpmTasks('grunt-contrib-cssmin');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-concat');
  
  // Register Grunt tasks
  grunt.task.registerTask('dist', ['vendor', 'sass', 'postcss', 'concat:premin', 'cssmin', 'concat:postmin', 'jshint', 'uglify:dist']);
  grunt.task.registerTask('css', ['sass', 'postcss', 'concat:premin', 'concat:postmin']);
  grunt.task.registerTask('js', ['jshint', 'uglify:dev']);
  grunt.task.registerTask('vendor', function() {
    var options = {
      'bower': 'bower_components',
      'js_dest': 'js/vendor/',
      'fonts_dest': 'font/'
    };
    grunt.log.subhead('Copying JavaScript files');
    var js = [
      ['<%= bower %>/jquery/dist/jquery.min.{js,map}'],
      ['<%= bower %>/ace-builds/src-min-noconflict/*.js', 'ace']
    ];
    for (var j = 0; j < js.length; j++) {
      var js_src = js[j][0];
      var js_dst = js[j][1] || '';
      var files = grunt.file.expand(grunt.template.process(js_src, {data: options}));
      for (var i = 0; i < files.length; i++) {
        var src = files[i];
        var paths = src.split('/');
        var dest = options.js_dest + js_dst + '/' + paths[paths.length - 1];
        grunt.file.copy(src, dest);
        grunt.log.writeln(">> ".green + src + " => " + dest.cyan);
      }
    }
    grunt.log.subhead('Copying font files');
    var fonts = [
      '<%= bower %>/font-awesome/fonts/*'
    ];
    for (var j = 0; j < fonts.length; j++) {
      var files = grunt.file.expand(grunt.template.process(fonts[j], {data: options}));
      for (var i = 0; i < files.length; i++) {
        var src = files[i];
        var paths = src.split('/');
        var dest = options.fonts_dest + paths[paths.length - 1];
        grunt.file.copy(src, dest);
        grunt.log.writeln(">> ".green + src + " => " + dest.cyan);
      }
    }
    grunt.task.run('uglify:vendor');
    grunt.task.run('uglify:vendor_nocompress');
  });
};

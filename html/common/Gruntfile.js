module.exports = function(grunt) {
  const sass = require('node-sass');
  require('es6-promise').polyfill();
  require('time-grunt')(grunt);

  grunt.initConfig({
    sass: {
      options: {
        implementation: sass,
        sourceMap: true,
        outFile: 'styles.css',
        noCache: true,
        includePaths: ['node_modules/inuitcss', 'scss/']
      },
      dist: {
        files: {
          'styles.css': 'scss/styles.scss'
        },
        options: {
          outputStyle: 'compressed'
        }
      },
      dev: {
        files: {
          'styles.css': 'scss/styles.scss'
        }
      }
    },
    postcss: {
      dist: {
        options: {
          map: false,
          processors: [
            require('autoprefixer')(),
            require('csswring').postcss // minifier
          ]
        },
        src: 'styles.css'
      },
      dev: {
        options: {
          map: true,
          processors: [
            require('autoprefixer')()
          ]
        },
        src: 'styles.css'
      }
    },
    watch: {
      grunt: {
        files: ['Gruntfile.js']
      },
      sass: {
        files: 'scss/*.scss',
        tasks: ['sass']
      }
    }
  });

  grunt.loadNpmTasks('grunt-sass');
  grunt.loadNpmTasks('grunt-postcss');
  grunt.loadNpmTasks('grunt-contrib-watch');

  // Build CSS for distribution
  grunt.task.registerTask('dist', ['sass:dist', 'postcss:dist']);

  // Tasks for developers
  grunt.task.registerTask('default', ['watch']);
  grunt.task.registerTask('dev', ['sass:dev', 'postcss:dev']);
};

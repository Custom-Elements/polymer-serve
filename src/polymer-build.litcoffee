Command line wrapper runner for vulcanization.

    doc = """
    Usage:
      polymer-build <source_directory> <build_directory>
      polymer-build watch <root_directory> <source_directory> <build_directory>
    """
    {docopt} = require 'docopt'
    args = docopt(doc)
    vulcanize = require 'vulcanize'
    recursive = require 'recursive-readdir'
    path = require 'path'
    fs = require 'fs'
    mkdirp = require 'mkdirp'
    async = require 'async'
    chokidar = require 'chokidar'
    express = require 'express'
    livereload = require 'express-livereload'
    require 'colors'

    mkdirp args['<build_directory>'], ->
      args.source_directory = fs.realpathSync args['<source_directory>']
      args.build_directory = fs.realpathSync args['<build_directory>']
      args.root_directory = fs.realpathSync args['<root_directory>'] or '.'
      waterfall = []

      recursive args.source_directory, (err, files) ->
        files.forEach (file) ->
          if path.extname(file) is '.html'
            console.log "found #{file}".blue
            waterfall.push (callback) ->
              vulcanizeOptions =
                preprocess: ['vulcanize-less', 'vulcanize-browserify']
                inline: true
                input: file
                output: file.replace(args.source_directory, args.build_directory)
                outputDir: path.dirname(file.replace(args.source_directory, args.build_directory))

Here is a bit of a special case, prevent polymer from being imported, this
will allow us to use polymer core elements without conflicts arising from
havign two different references to polymer.

                excludes:
                  imports: ['polymer.html']
              vulcanize.setOptions vulcanizeOptions, (e) ->
                console.log "building #{vulcanizeOptions.input} to #{vulcanizeOptions.output}".green
                if e
                  callback(e)
                else
                  vulcanize.processDocument (e) ->
                    console.log "built".blue
                    callback(e)

At this point the waterfall is built and ready to run.

        async.waterfall waterfall, (e) ->
          console.error("#{e}".red) if e

Are we watching?

        if args.watch
          port = process.env['PORT'] or 10000
          app = express()
          app.use(express.static(args.root_directory))
          livereload app,
            port: 35729
            watchDir: args.build_directory
          app.listen port
          console.log "http://localhost:#{port}/demo.html"
          watcher = chokidar.watch args.source_directory
          watcher.on 'change', ->
            async.waterfall waterfall, (e) ->
              console.error("#{e}".red) if e




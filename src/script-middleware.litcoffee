Express middleware to build and serve on demand.

    parseurl = require 'parseurl'
    path = require 'path'
    browserify = require 'browserify'
    through = require 'through'
    uglify = require 'uglify-js'
    fs = require 'fs'
    Promise = require 'bluebird'

    requireString = (extension) ->
      escapeContent = (content) ->
        content.replace(/\\/g, '\\\\').replace(/'/g, '\\\'').replace(/\r?\n/g, '\\n\' +\n    \'')
      contentExport = (content) ->
        "module.exports = '" + escapeContent(content) + "';"
      (file) ->
        data = ''
        write = (buffer) ->
          data += buffer
        end = ->
          stream = this
          fs.readFile file, 'utf8', (err, content) ->
            if err
              stream.emit 'error', e
            else
              stream.queue contentExport(content)
              stream.queue null
        if path.extname(file) is extension
          through write, end
        else
          through()
          
    module.exports = (args, directory) ->
      compile = (filename) ->
        console.log "scripting with browserify", filename.blue
        b = browserify
          debug: true unless args.cache
          fullPaths: true
        b.add filename
        b.transform requireString '.svg'
        b.transform require 'coffeeify'
        new Promise (resolve, reject) ->
          b.bundle (err, compiled) ->
            if err?
              reject err
            else
              resolve compiled
        .then (compiled) ->
          if args.cache
            compiled = uglify.minify compiled.toString(), fromString: true
            compiled = compiled.code
            args.cache[filename] = compiled
          compiled
      compile: compile

      get: (req, res, next) ->
          if 'GET' isnt req.method and 'HEAD' isnt req.method
            return next()
          filename = path.join directory or process.cwd(), parseurl(req).pathname
          res.setHeader 'Last-Modified', args.lastModified ? new Date().toUTCString()

          if path.extname(filename) is '.litcoffee' or path.extname(filename) is '.coffee'
            if args.cache?[filename]
              res.type 'application/javascript'
              res.send(args.cache[filename]).end()
              return
              
            compile filename
              .then (compiled) ->
                res.type 'application/javascript'
                res.send(compiled)
              .error (err) ->
                console.error err.toString().red
                res.set 'Error', err.toString()
                res.send err.toString(), 400
                res.end()
          else
            next()

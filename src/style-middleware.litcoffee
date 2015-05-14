Express middleware to build and serve on demand.

    parseurl = require 'parseurl'
    less = require 'less'
    path = require 'path'
    fs = require 'fs'
    Promise = require 'bluebird'

    Promise.promisifyAll fs
    Promise.promisifyAll less

    module.exports = (args, directory) ->
      compile = (filename) ->
        console.log "styling ", filename.blue
        cssOptions =
          relativeUrls: true
          compress: true
          filename: filename
          paths: [
            path.dirname(filename)
            directory
            process.cwd()
            ]
        fs.readFileAsync(filename, 'utf-8')
          .then (rawLess) ->
            less.renderAsync rawLess, cssOptions
          .then (compiled) ->
            if args.cache
              args.cache[filename] = compiled.css
            compiled.css
      compile: compile

      get: (req, res, next) ->
          if 'GET' isnt req.method and 'HEAD' isnt req.method
            return next()
          filename = path.join directory or process.cwd(), parseurl(req).pathname
          res.setHeader 'Last-Modified', args.lastModified ? new Date().toUTCString()

          if path.extname(filename) is '.less'
            if args.cache?[filename]
              res.type 'text/css'
              res.send(args.cache[filename]).end()
              return
            compile(filename)
              .then (compiled) ->
                res.type 'text/css'
                res.send(compiled).end()
              .error (e) ->
                res.statusCode = 500
                res.end e.message
          else
            next()

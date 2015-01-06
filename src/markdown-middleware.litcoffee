Express middleware to build and serve on demand.

    parseurl = require 'parseurl'
    less = require 'less'
    path = require 'path'
    Promise = require 'bluebird'
    marked = require 'marked'
    fs = require 'fs'

    Promise.promisifyAll fs

    renderer = new marked.Renderer()
    renderer.code = (code, language) ->
      "<ui-code language='#{language}'>#{code}</ui-code>"
    renderer.listitem = (text) ->
      "<li dotted>#{text}</li>"

    module.exports = (args, directory) ->
      (req, res, next) ->
        if 'GET' isnt req.method and 'HEAD' isnt req.method
          return next()
        filename = path.join directory or process.cwd(), parseurl(req).pathname
        if path.extname(filename) is '.md'
          console.log "marking down", filename.blue
          fs.readFileAsync(filename, 'utf-8')
            .then( (markdown) ->
              content = marked markdown, renderer: renderer
              res.type 'text/plain'
              res.statusCode = 200
              res.end content
            )
            .error( (e) ->
              res.statusCode = 500
              res.end e.message
            )
        else
          next()

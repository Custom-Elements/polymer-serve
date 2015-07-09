Things to make docs

    mustache = require 'mustache'
    path = require 'path'
    fs = require 'fs'
    globby = require 'globby'
    _ = require 'lodash'

    module.exports = (args, directory) ->

      src = [
        './elements/**/*.html'
        '!./elements/**/demo/*.html'
        '!./elements/index.html'
        '!./elements/**/preview.html'
      ]

      docTemplateSrc = path.join(__dirname,'../templates/docs.mustache')

      (req,res) ->
        globby src, { cwd: directory } , (err,paths) ->
          links = _.map paths, (link) ->
            link = { element: path.basename(link).replace('.html','') }
            link.url = "./elements/#{link.element}/#{link.element}.html"
            link
          fs.readFile docTemplateSrc, {encoding: 'utf8'} , (err, file) ->
            res.type 'text/html'
            console.err(err) if err
            res.end(mustache.render(file, { links }))
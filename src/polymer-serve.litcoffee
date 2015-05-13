Command line wrapper for polymer element compiling server. This uses
a set of custom middleware to give you Polymer elements on the fly
with LESS/CoffeeScript/Browserify support built in.

The idea is that `<link rel="import">` tags will request content from this
server, which will be transpiled into polymer ready browser custom elements.

    doc = """
    Usage:
      polymer-serve [options] <root_directory>


      --help             Show the help
      --cache            Only build just once, then save the results.
      --precache         Precompile and cache all resources before starting, implies --cache
      --quiet            SSSHHH! Less logging.
    """
    {docopt} = require 'docopt'
    _ = require 'lodash'
    args = docopt(doc)
    Promise = require 'bluebird'
    Path = Promise.promisifyAll require 'path'
    fs = Promise.promisifyAll require 'fs'
    express = require 'express'
    cluster = require 'cluster'
    walk = require 'walk'
    cheerio = require 'cheerio'
    require 'colors'

    args.root_directory = fs.realpathSync args['<root_directory>'] or '.'

Set up a cache holding object if requested, the middlewares will look for this
and just use it rather than running.

    if args['--cache'] or args['--precache']
      console.log "enabling production cache".green
      args.lastModified = new Date().toUTCString()
      args.cache = {}

    port = process.env['PORT'] or 10000

Using cluster to get a faster build -- particularly on the initial request.

    if cluster.isMaster and not args.cache
      if fs.existsSync Path.join(args.root_directory, 'demo.html')
        console.log "Test Page".blue, "http://localhost:#{port}/demo.html"
      cpuCount = require('os').cpus().length * 2
      ct = 0
      while ct < cpuCount
        cluster.fork()
        ct++
    else
      app = express()
      app.set 'etag', true
      app.use require('cors')()

      app.use require('./polymer-middleware.litcoffee')(args, args.root_directory)
      app.use require('./style-middleware.litcoffee')(args, args.root_directory).get
      app.use require('./script-middleware.litcoffee')(args, args.root_directory).get
      app.use require('./markdown-middleware.litcoffee')(args, args.root_directory).get
      
      markdownCompiler = require('./markdown-middleware.litcoffee')(args, args.root_directory).compile
      scriptCompiler = require('./script-middleware.litcoffee')(args, args.root_directory).compile
      styleCompiler = require('./style-middleware.litcoffee')(args, args.root_directory).compile

      app.use express.static(args.root_directory)

Optional precache step to precompile and populate the cache, before the server becomes available

      if args['--precache']
        console.log "enabling precompilation".green
        paths = []
        walker = walk.walk args.root_directory, { filters: ["polymer"] }
        walker.on 'file', (dir, stats, next) ->
          path = Path.join(dir, stats.name)#.replace new RegExp("^#{args.root_directory}"), ""
          if Path.extname(path) is '.html'
            fs.readFileAsync path, "utf8"
            .then (html) ->
              $ = cheerio.load html
              $('link[rel=stylesheet]').map (index, element) ->
                href = $(this).attr 'href'
                if Path.extname(href) is '.less'
                  file = Path.join dir, href
                  # if file.lastIndexOf 'node_modules' isnt -1
                  #   file = file.substring file.lastIndexOf 'node_modules'
                  # if exists
                  paths.push file
              $('script').map (index, element) ->
                src = $(this).attr 'src'
                if Path.extname(src) in ['.coffee', '.litcoffee']
                  file = Path.join dir, src
                  # if file.lastIndexOf 'node_modules' isnt -1
                  #   file = file.substring file.lastIndexOf 'node_modules'
                  paths.push file
              next()
              # if file.match /\.(coffee|litcoffee|less|md)$/
              #   mockRequest(app).get(file).end -> next()
          else
            next()
        walker.on 'end', ->
            Promise.map _.uniq(paths), (path) ->
              fs.statAsync path
                .then (stat) ->
                  if stat.isFile()
                    ext = Path.extname path
                    return scriptCompiler(path) if ext in ['.coffee', '.litcoffee']
                    return styleCompiler(path) if ext in ['.less']
                  return path
                .catch (err) ->
                  console.log "*** #{path} #{err}"
                  return path
            , { concurrency: 1 }
            .then ->
              console.log "Precalessche completed, starting server...".green
              app.listen port
      else
        app.listen port

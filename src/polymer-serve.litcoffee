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
      --quiet            SSSHHH! Less logging.
    """
    {docopt} = require 'docopt'
    _ = require 'lodash'
    args = docopt(doc)
    path = require 'path'
    fs = require 'fs'
    express = require 'express'
    cluster = require 'cluster'
    require 'colors'

    args.root_directory = fs.realpathSync args['<root_directory>'] or '.'

Set up a cache holding object if requested, the middlewares will look for this
and just use it rather than running.

    if args['--cache']
      console.log "enabling production cache".green
      args.cache = {}

    port = process.env['PORT'] or 10000

Using cluster to get a faster build -- particularly on the initial request.

    if cluster.isMaster and not args.cache
      if fs.existsSync path.join(args.root_directory, 'demo.html')
        console.log "Test Page".blue, "http://localhost:#{port}/demo.html"
      cpuCount = require('os').cpus().length * 2
      ct = 0
      while ct < cpuCount
        cluster.fork()
        ct++
    else
      app = express()
      app.enable 'etag'
      app.use require('cors')()

      app.use require('./polymer-middleware.litcoffee')(args, args.root_directory)
      app.use require('./style-middleware.litcoffee')(args, args.root_directory)
      app.use require('./script-middleware.litcoffee')(args, args.root_directory)
      app.use require('./markdown-middleware.litcoffee')(args, args.root_directory)

      app.use express.static(args.root_directory)
      app.listen port

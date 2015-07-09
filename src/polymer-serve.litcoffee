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
    dir = require 'node-dir'
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
        console.log "Test Page".blue, "http://localhost:#{port}/demo.html".green
      else
        console.log "Documentation Page".blue, "http://localhost:#{port}/".green
      cpuCount = require('os').cpus().length * 2
      ct = 0
      while ct < cpuCount
        cluster.fork()
        ct++
    else
      app = express()
      app.set 'etag', true

      app.use require('./polymer-middleware.litcoffee')(args, args.root_directory)
      app.use require('./style-middleware.litcoffee')(args, args.root_directory).get
      app.use require('./script-middleware.litcoffee')(args, args.root_directory).get
      app.use require('./markdown-middleware.litcoffee')(args, args.root_directory).get

      compileMarkdownAsync = require('./markdown-middleware.litcoffee')(args, args.root_directory).compile
      compileScriptAsync = require('./script-middleware.litcoffee')(args, args.root_directory).compile
      compileStyleAsync = require('./style-middleware.litcoffee')(args, args.root_directory).compile

      app.use express.static(args.root_directory)

      app.get '/', require('./documentation-middleware.litcoffee')(args, args.root_directory)

Optional precache step to precompile and populate the cache, before the server becomes available

      if not args['--precache']
        app.listen port
      else
        console.log "beginning precompilation...".green

        onReadFile = (err, html, filename, next) ->
          throw err if err
          parseHTML(filename, html).then -> next()

        options =
          match: /.html$/
          excludeDir: [ 'polymer', 'polymer-serve' ]

        dir.readFiles args.root_directory, options, onReadFile, (err, files) ->
          throw err if err?
          console.log "Precache completed, starting server...".green
          app.listen port

Parse the the html, pulling out all references that might need to be compiled

        parseHTML = (filename, html) ->
          # console.log "Parsing #{filename}"
          $ = cheerio.load html
          dir = Path.dirname filename

          paths = []
          $('link[rel=stylesheet]').map (index, element) ->
            href = $(this).attr('href')
            paths.push Path.join dir, href if href? and Path.extname(href) is '.less'

          $('script').map (index, element) ->
            src = $(this).attr('src')
            paths.push Path.join dir, src if src? and Path.extname(src) in [ '.coffee', '.litcoffee']

          # todo - compile markdown files to html, then parse the html, probably not worth the trouble

          return compile _.filter paths, (path) ->
            ignoredDirectories = _.intersection options.excludeDir, path.split '/'
            ignoredDirectories.length is 0

Compile the paths, which caches the result as a side effect

        compile = (paths) ->
          Promise.map paths, (path) ->
            if args.cache[path]
              return console.log "Skipping duplicate import '#{path}'".yellow
            fs.statAsync path
              .then (stat) ->
                if stat.isFile()
                  ext = Path.extname path
                  if ext is '.less'
                    compileStyleAsync(path)
                  else if ext in ['.coffee', '.litcoffee']
                    compileScriptAsync(path)
              .catch (err) ->
                console.log "File not found: '#{path}'".red


http    = require('http')
express = require('express')
path    = require('path')
favicon = require('serve-favicon')
fs      = require('fs')
yaml    = require('js-yaml')

basePath      = path.join(__dirname, '..')
generatedPath = path.join(basePath, '.generated')
vendorPath    = path.join(basePath, 'bower_components')
faviconPath   = path.join(basePath, 'app', 'favicon.ico')

class WebServer

  constructor: (github) ->
    @app    = express()
    @server = http.createServer(@app)
    @configureServer()
    @setupRoutes(github)

  configureServer: ->
    @app.engine('.html', require('hbs').__express)

    @app.use(favicon(faviconPath))
    @app.use('/assets', express.static(generatedPath))
    @app.use('/vendor', express.static(vendorPath))

    port = process.env.PORT || 3002
    @server.listen(port)

  getDataFile: (file) ->
    try
      filepath = path.join(basePath, 'data', file + '.yaml')
      doc = yaml.safeLoad(fs.readFileSync(filepath, 'utf8'))
    catch err
      console.log(err)

  setupRoutes: (github) ->
    repos = @getDataFile('repos')

    @app.get '/', (req, res) =>
      res.render(path.join(generatedPath, 'index.html'))

    @app.get '/repos', (req, res) -> res.send(github.repos)




module.exports = WebServer

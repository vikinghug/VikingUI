should = require("should")
expect = require("chai").expect
io = require('socket.io-client')
Main = require('../lib/main.coffee')

socketURL = 'http://localhost:3002'

ioOpts = {}

client = io.connect(socketURL, ioOpts)

describe "When Main is initialized the client:", ->

  db = {}

  before (done) ->
    client.on "connect", ->
      db.connected = true

    client.on "HELLO", ->
      db.hello = true
      client.emit 'request repos manifest'

    client.on 'update repos manifest', (data) ->
      db.repos = data
      @removeAllListeners()
      done()

  it 'should connect to Main socket server successfully', ->
    db.connected.should.be.true

  it 'should receive a "HELLO" event from the Main socket server', ->
    db.hello.should.be.true

  it 'should receive an array from "repo" event', ->
    db.repos.should.be.an.Array


_            = require('underscore')
path         = require('path')
cs           = require('calmsoul')
fs           = require('fs')
github       = require('octonode')
yaml         = require('js-yaml')
WatchJS      = require("watchjs")
watch        = WatchJS.watch
unwatch      = WatchJS.unwatch
callWatchers = WatchJS.callWatchers
EventEmitter = require('events').EventEmitter
VM           = require('./version-manager.coffee')

# this is a generic token
# 894b9db89f78b7142263966c69cabf63cec31a19
# d34475bc0818fbc70158f0aca9a488523a6d4470
# Nimmock: 96234b48504bcb43a1d0a9e11cd7e596b45f4e54
# Mormur: 16cd039c3347e9689bf2e7d3eccdcfb627bec2fc
# fasma: 3fe23a32720c1d08a38dc488c3e5128ea809fdaa
keys = [
  "894b9db89f78b7142263966c69cabf63cec31a19"
  "96234b48504bcb43a1d0a9e11cd7e596b45f4e54"
  "16cd039c3347e9689bf2e7d3eccdcfb627bec2fc"
  "3fe23a32720c1d08a38dc488c3e5128ea809fdaa"
  "684de5ec8b53c6dafc141c0a6b04c3b5ea13cae9"
  "217c16b8d336c8d3a4bcba502cac2496c5a234e8"
  "9bcf601037685ba1c8b87b5ce2fd4155529986cf"
  "696ebed17e1317d0833aac574045d95df74c3432"]


getKey = -> return keys[Math.floor(Math.random() * keys.length)]

client   = github.client(getKey())
basePath = path.join(__dirname, '..')

cs.set
  info: false

class Github extends EventEmitter

  blacklist: [
    "AddonDownloader"
    "VikingAPI"
    "VikingBuddies"
    "vikingcli"
    "VikingDatachron"
    "VikingDocs"
    "vikinghug.com"
    "VikingQuestTracker"
    "VikingRaidFrame"
    "VikingSet"
    "VikingStalkerResource"
    "VikingWarriorResource"
  ]

  whitelist: []

  repos: []
  owner: null

  queue: []

  constructor: (owner) ->
    cs.info '\n\n@@Github::constructor ->'
    @whitelist = @getDataFile('repos')
    @owner = owner

    @clearQueue = _.throttle(@_clearQueue, 200)

    @getRepos()
    setInterval =>
      @getRepos()
    , 16000

  getDataFile: (file) ->
    try
      filepath = path.join(basePath, 'data', file + '.yaml')
      doc = yaml.safeLoad(fs.readFileSync(filepath, 'utf8'))
    catch err
      cs.debug(err)

  setRepos: (repos) -> @repos = repos

  findRepo: (_repo) ->
    return null if @repos.length == 0

    for repo, i in @repos
      if _repo.id == repo.id or _repo.name == repo.name
        return i
    return null

  getRepos: ->
    cs.info "getRepos: ->", getKey()
    org = client.org(@owner)
    self = this
    org.repos (err, array, headers) =>
      if err && err.statusCode == 403
        client = github.client(getKey())
        self.getRepos()
        cs.info "github::getRepos: ERROR: 403"
        return
      else cs.info "github::getRepos: SUCCESS"
      array = @filterForBlacklist(array)

      for repo, i in array
        @initRepo(repo, i)

      @sort(@repos)

  setUpdated: (payload, updated, tooltip) ->
    payload.tooltip = tooltip
    payload.recent_update = updated

  initRepo: (repo, i) ->
    payload =
      id                : repo.id
      owner             : repo.owner.login
      name              : repo.name
      git_url           : repo.git_url
      html_url          : repo.html_url
      ssh_url           : repo.ssh_url
      issues_url        : "#{repo.html_url}/issues"
      branches          : null
      open_issues_count : repo.open_issues_count
      pushed_at         : repo.pushed_at
      recent_update     : false
      tooltip           : null
      version           : null

    @checkForRecentUpdate(payload, @setUpdated.bind(payload))

    index = @findRepo(repo)
    if index?
      @repos[index] = payload
    else
      @repos.push(payload)

    @runCommand("branches", payload, @updateBranches)


  checkForRecentUpdate: (payload, callback) ->
    try
      self = this
      repo = client.repo("#{@owner}/#{payload.name}")
      repo.commit 'master', (err, data, headers) =>
        if err && err.statusCode == 403
          client = github.client(getKey())
          self.checkForRecentUpdate(payload, callback)
          cs.debug "github::checkForRecentUpdate: ERROR: 403"
          return
        else cs.debug "github::checkForRecentUpdate: SUCCESS"
        past  = new Date(data.commit.author.date).getTime()
        now   = new Date().getTime()
        delta = Math.abs(now - past) / 1000
        callback(payload, Math.floor(delta / 3600) < 12, data.commit.message)
    catch err
      cs.debug err


  addToQueue: (fn, args...) ->
    @queue.push([fn, args])

  _clearQueue: ->
    if @queue.length > 0
      try
        fn = @queue.shift()
        fn[1].push(@clearQueue)
        fn[0].apply(this, fn[1])
      catch err
        @emit('MESSAGE:ADD', err.message)
    else
      @emit('MESSAGE:ADD', "ALL DONE!")

  done: -> @clearQueue()

  updateBranches: (payload, callback) ->
    self = this
    repo = client.repo("#{@owner}/#{payload.name}")
    for branch, i in payload.branches
      branch.html_url = "#{payload.html_url}/tree/#{branch.name}"
      branch.download_url = "#{payload.git_url}\##{branch.name}"
      @addToQueue(@getBranchVersion, repo, payload, branch, @setBranchVersion)
    @clearQueue()

  setMasterVersion: (payload, version) ->
    payload.version = version ? "nil"

  getBranchVersion: (repo, payload, branch, callback) ->
    self = this
    repo.contents 'toc.xml', branch.name, (err, data, headers) =>
      if err && err.statusCode == 403
        client = github.client(getKey())
        self.getBranchVersion(repo, payload, branch, callback)
        cs.debug "github::getAddonVersions: ERROR: 403"
        return
      else cs.debug "github::getAddonVersions: SUCCESS"
      try
        version = VM.getVersion(data.content) if data? and data.content?
        version = if version < branch.version then branch.version else version
        callback.apply(self, [payload, branch, version, self.done]) if callback
        return
      catch err
        cs.debug err
      # callback

  setBranchVersion: (payload, branch, version, callback) ->
    b = _.findWhere(payload.branches, {name: branch.name})
    _.extend(branch, {version: version})
    @setMasterVersion(payload, version) if branch.name == "master"
    callback.apply(this) if callback


  filterForWhitelist: (array) ->
    self = this
    repos = array.filter (repo) ->
      n = 0
      self.blacklist.map (name) => n += (repo.name == name)
      return repo if n > 0

  filterForBlacklist: (array) ->
    self = this
    return array.filter (repo) ->
      n = 0
      self.blacklist.map (name) => n += (repo.name == name)
      return repo if n == 0

  sort: (repos) ->
    repos.sort (a,b) ->
      aStr = a.name.toLowerCase()
      bStr = b.name.toLowerCase()
      if (aStr > bStr)
        return 1
      else if (bStr > aStr)
        return -1
      else
        return 0

  runCommand: (command, data, callback) ->
    repo = client.repo("#{data.owner}/#{data.name}")
    repo[command] (err, response, headers) =>
      obj = {}
      obj[command] = response
      _.extend( data, obj )
      callback.apply(this, [data]) if callback?



module.exports = Github

Backbone = require 'backbone'
mongo    = require 'mongodb'
logger   = require './logging'
events   = require 'events'
_        = require 'underscore'
models   = require '../assets/js/models'

_connection = null

open = (opts, callbacks) ->
  if _connection?
    if callbacks.success? then callbacks.success(_connection)
    return _connection

  connector = new mongo.Db(
    opts.dbname,
    new mongo.Server(opts.dbhost, opts.dbport, opts.dbopts)
  )

  connector.open (err, database) ->
    if (err)
      if callbacks.error? then callbacks.error(err)
      logger.error(err)
    else
      _connection = database
      callbacks.success(_connection) if callbacks.success?

Backbone.sync = (method, model, options) ->
  cb = options.success or (->)
  cberr = (err) ->
    logger.error(err)
    options.error?(err)
  unless _connection?
    cberr "Not connected to the database."
    return

  collectionName = model.collectionName
  unless collectionName?
    cberr "No collectionName found for model or collection."
    return

  _connection.collection collectionName, (err, coll) ->
    if err
      return cberr(err)
    done = (err, result) ->
      if err
        cberr(err)
      else
        Model = models.modelFromCollectionName(collectionName)
        newModel = new Model(result[0])
        Backbone.sync.emit "after:#{method}:#{model.collectionName}", newModel
        cb(result[0])

    if model.id? or options.query?._id?
      _id = mongo.ObjectID.createFromHexString("" + (model.id or options.query._id))
    else
      _id = undefined

    Backbone.sync.emit "before:#{method}:#{model.collectionName}", model
    switch method
      when "create"
        coll.insert model.toJSON(), {safe: true}, done
      when "update"
        data = model.toJSON()
        data._id = _id
        coll.update {_id: _id}, data, {safe: true}, done
      when "delete"
        coll.remove {_id: _id}, {safe: true}, done
      when "read"
        query = options.query or model.toJSON()
        if query._id?
          query._id = _id

        coll.find(query).toArray (err, items) ->
          if err
            cberr(err)
          else
            if model instanceof Backbone.Model
              cb(items[0])
            else
              cb(items)

_.extend Backbone.sync, events.EventEmitter.prototype

module.exports = { open }

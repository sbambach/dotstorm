mongoose   = require 'mongoose'
Schema     = mongoose.Schema
uuid       = require 'node-uuid'
_          = require 'underscore'
thumbnails = require './thumbnails'

#
# Ideas
#

# Voter: embedded in Idea.
VoterSchema = new Schema
  user: {type: Schema.ObjectId, ref: 'User' }
  session_id: { type: String }
VoterSchema.pre 'save', (next) ->
  if not @user? or @session_id?
    next(new Error("Either user or session_id required"))
  else
    next()
Voter = mongoose.model("Voter", VoterSchema)

# Idea
IdeaSchema = new Schema
  author: { type: Schema.ObjectId, ref: 'User' }
  votes: [VoterSchema]
  dotstorm_id: { type: Schema.ObjectId, required: true }
  imageVersion: {
    type: Number
    set: (v) ->
      if v != @imageVersion then @_updateThumbnails = true
      return v
  }
  photoVersion: {
    type: Number
    set: (v) ->
      if v != @photoVersion then @incImageVersion()
      return v
  }
  background: {
    type: String
    set: (v) ->
      if v != @background then @incImageVersion()
      return v
  }
  description: {
    type: String
    set: (v) ->
      if v != @description then @incImageVersion()
      return v
  }
  tags: [{
    type: String
    set: (v) ->
      return v.replace(/[^-\w\s]/g, '').trim()
  }]
  created: Date
  modified: Date
  drawing:
    type: [Schema.Types.Mixed]
    set: (v) ->
      unless (not v) or _.isEqual(v, @drawing) then @incImageVersion()
      return v
IdeaSchema.pre 'save', (next) ->
  # Update timestamps
  unless @created
    @set 'created', new Date().getTime()
  @set 'modified', new Date().getTime()
  next()
IdeaSchema.pre 'save', (next) ->
  # Save photos.
  if @photoData
    console.log "photo data!"
    @photoVersion = (@get("photoVersion") or 0) + 1
    thumbnails.photoThumbs this, @photoData, (err) =>
      if err?
        next(new Error(err))
      else
        delete @photoData
        @incImageVersion()
        next(null)
  else
    console.log "no photo data!"
    next(null)
IdeaSchema.pre 'save', (next) ->
  # Assemble drawings and thumbnails.
  if @_updateThumbnails
    delete @_updateThumbnails
    unless @background
      next(new Error("Can't draw drawing without background"))
    else
      thumbnails.drawingThumbs this, (err) ->
        if err?
          next(new Error(err))
        else
          next(null)
  else
    next(null)
IdeaSchema.pre 'remove', (next) ->
  thumbnails.remove this, (err) ->
    if err?
      next(new Error(err))
    else
      next(null)
IdeaSchema.virtual('photoURLs').get ->
    photos = {}
    if @photoVersion?
      for size in ["small", "medium", "large", "full"]
        photos[size] = "/uploads/idea/#{@id}/photo/#{size}#{@photoVersion}.png"
    return photos
IdeaSchema.virtual('drawingURLs').get ->
    thumbs = {}
    if @imageVersion?
      for size in ["small", "medium", "large", "full"]
        thumbs[size] = "/uploads/idea/#{@id}/drawing/#{size}#{@imageVersion}.png"
    return thumbs
IdeaSchema.virtual('taglist').get(
  -> return @tags.join(", ")
).set(
  (taglist) -> @set 'tags', taglist.split(/,\s*/)
)
IdeaSchema.statics.findOneLight = (constraint, cb) ->
  return @findOne constraint, { "drawing": 0 }, cb
IdeaSchema.statics.findLight = (constraint, cb) ->
  return @find constraint, { "drawing": 0 }, cb
Idea = mongoose.model("Idea", IdeaSchema)
Idea.prototype.incImageVersion = ->
  @set "imageVersion", (@imageVersion or 0) + 1
Idea.prototype.DIMS = { x: 600, y: 600 }
Idea.prototype.getDrawingPath = (size) ->
  if @drawingURLs[size]?
    return thumbnails.BASE_PATH + @drawingURLs[size]
  return null
Idea.prototype.getPhotoPath = (size) ->
  if @photoURLs[size]?
    return thumbnails.BASE_PATH + @photoURLs[size]
  return null
Idea.prototype.serialize = ->
  json = @toJSON()
  json.drawingURLs = @drawingURLs
  json.photoURLs = @photoURLs
  json.taglist = @taglist
  return json

#
# Dotstorms
#

# Idea Group: for sorting/ordering of ideas; embedded in dotstorm.
IdeaGroupSchema = new Schema
  _id: { type: String }
  label: { type: String, trim: true }
  ideas: [{type: Schema.ObjectId, ref: 'Idea'}]
IdeaGroup = mongoose.model("IdeaGroup", IdeaGroupSchema)

# Dotstorm
DotstormSchema = new Schema
  slug:
    type: String
    required: true
    unique: true
    trim: true
    match: /[-a-zA-Z0-9]+/
  embed_slug: {type: String, required: true, default: uuid.v4}
  name: { type: String, required: false, trim: true }
  topic: { type: String, required: false, trim: true }
  groups: [IdeaGroupSchema]
Dotstorm = mongoose.model("Dotstorm", DotstormSchema)
Dotstorm.withLightIdeas = (constraint, cb) ->
  return Dotstorm.findOne(constraint).populate(
    'groups.ideas', { 'drawing': 0 }
  ).run cb
Dotstorm.prototype.serialize = ->
  return @toJSON()

module.exports = { Dotstorm, IdeaGroup, Idea }

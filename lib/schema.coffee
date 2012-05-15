mongoose   = require 'mongoose'
Schema     = mongoose.Schema
uuid       = require 'node-uuid'
_          = require 'underscore'
thumbnails = require './thumbnails'

VoterSchema = new Schema
  user: {type: Schema.ObjectId, ref: 'User' }
  session_id: { type: String }
VoterSchema.pre 'save', (next) ->
  if not @user? or @session_id?
    next(new Error("Either user or session_id required"))
  else
    next()
Voter = mongoose.model("Voter", VoterSchema)

IdeaSchema = new Schema
  author: { type: Schema.ObjectId, ref: 'User' }
  votes: [VoterSchema]
  dotstorm_id: { type: Schema.ObjectId, required: true }
  imageVersion: { type: Number }
  photoVersion: { type: Number }
  background: { type: String, match: /^#[a-f0-9]{6}$/ }
  description: { type: String }
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
      unless (not v) or _.isEqual v, @drawing
        @imageVersion ||= 0
        @imageVersion++
        @updateThumbnails = true
      return v
IdeaSchema.pre 'save', (next) ->
  unless @created
    @set 'created', new Date().getTime()
  @set 'modified', new Date().getTime()
  if @updateThumbnails
    delete @updateThumbnails
    unless @background
      next new Error("Can't draw drawing without background")
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
IdeaSchema.virtual('photoURLs')
  .get ->
    photos = {}
    if @photoVersion?
      for size in ["small", "medium", "large", "full"]
        photos[size] = "/uploads/idea/#{@id}/photo/#{size}#{@photoVersion}.png"
    return photos
IdeaSchema.virtual('drawingURLs')
  .get ->
    thumbs = {}
    if @drawing.length
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
Idea.prototype.DIMS = { x: 600, y: 600 }
Idea.prototype.getDrawingPath = (size) ->
  return thumbnails.BASE_PATH + @drawingURLs[size]
Idea.prototype.getPhotoPath = (size) ->
  return thumbnails.BASE_PATH + @photoURLs[size]

IdeaGroupSchema = new Schema
  label: { type: String, trim: true }
  ideas: [{type: Schema.ObjectId, ref: 'Idea'}]
IdeaGroup = mongoose.model("IdeaGroup", IdeaGroupSchema)

DotstormSchema = new Schema
  slug:
    type: String
    required: true
    unique: true
    trim: true
    match: /[-a-zA-Z0-9]+/
  name: { type: String, required: false, trim: true }
  description: { type: String, required: false, trim: true }
  groups: [IdeaGroupSchema]
Dotstorm = mongoose.model("Dotstorm", DotstormSchema)
Dotstorm.withLightIdeas = (constraint, cb) ->
  return Dotstorm.findOne(constraint).populate(
    'groups.ideas', { 'drawing': 0 }
  ).run cb

module.exports = { Dotstorm, IdeaGroup, Idea }

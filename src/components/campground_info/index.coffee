z = require 'zorium'
_map = require 'lodash/map'
_isEmpty = require 'lodash/isEmpty'

Icon = require '../icon'
InfoLevelTabs = require '../info_level_tabs'
InfoLevel = require '../info_level'
EmbeddedVideo = require '../embedded_video'
Rating = require '../rating'
colors = require '../../colors'
config = require '../../config'

if window?
  require './index.styl'

module.exports = class CampgroundInfo
  constructor: ({@model, @router, place}) ->
    seasons =  [
      {key: 'spring', text: @model.l.get 'seasons.spring'}
      {key: 'summer', text: @model.l.get 'seasons.summer'}
      {key: 'fall', text: @model.l.get 'seasons.fall'}
      {key: 'winter', text: @model.l.get 'seasons.winter'}
    ]
    currentSeason = 'fall' # TODO
    @$crowdsInfoLevelTabs = new InfoLevelTabs {
      @model, @router, tabs: seasons
      selectedTab: currentSeason, key: 'crowds'
    }
    @$fullnessInfoLevelTabs = new InfoLevelTabs {
      @model, @router, tabs: seasons
      selectedTab: currentSeason, key: 'fullness'
    }
    @$noiseInfoLevelTabs = new InfoLevelTabs {
      @model, @router,
      tabs: [
        {key: 'day', text: @model.l.get 'general.day'}
        {key: 'night', text: @model.l.get 'general.night'}
      ]
      selectedTab: 'day'
      key: 'noise'
    }
    @$shadeInfoLevel = new InfoLevel {@model, @router, key: 'shade'}
    @$safetyInfoLevel = new InfoLevel {@model, @router, key: 'safety'}
    @$roadDifficultyInfoLevel = new InfoLevel {
      @model, @router, key: 'roadDifficulty'
    }
    @$rating = new Rating {
      rating: place.map (place) -> 3.3 # FIXME place.rating
    }

    @state = z.state
      place: place.map (place) =>
        {
          place
          $videos: _map place.videos, (video) =>
            new EmbeddedVideo {@model, video}
        }

  render: =>
    {place} = @state.getValue()

    {place, $videos} = place or {}

    z '.z-campground-info',
      z '.g-grid',
        z '.location',
          'City, ST' # TODO
        z '.rating',
          z @$rating, {size: '20px'}
        if place?.drivingInstructions
          z '.title', @model.l.get 'campground.drivingInstructions'
          place?.drivingInstructions
        # TODO distances to amenities
        z '.g-cols',
          z '.g-col.g-xs-12.g-md-6',
            z '.title', @model.l.get 'campground.crowds'
            z @$crowdsInfoLevelTabs, {
              value: place?.crowds
              min: 1
              max: 5
            }
          z '.g-col.g-xs-12.g-md-6',
            z '.title', @model.l.get 'campground.fullness'
            z @$fullnessInfoLevelTabs, {
              value: place?.fullness
              min: 1
              max: 5
            }
          z '.g-col.g-xs-12.g-md-6',
            z '.title', @model.l.get 'campground.noise'
            z @$noiseInfoLevelTabs, {
              value: place?.noise
              min: 1
              max: 5
            }
          z '.g-col.g-xs-12.g-md-6',
            z '.title', @model.l.get 'campground.shade'
            z @$shadeInfoLevel, {
              value: place?.shade
              min: 1
              max: 5
            }
          z '.g-col.g-xs-12.g-md-6',
            z '.title', @model.l.get 'campground.safety'
            z @$safetyInfoLevel, {
              value: place?.safety
              min: 1
              max: 5
            }
          z '.g-col.g-xs-12.g-md-6',
            z '.title', @model.l.get 'campground.roadDifficulty'
            z @$roadDifficultyInfoLevel, {
              value: place?.roadDifficulty
              min: 1
              max: 5
            }

          unless _isEmpty $videos
            z '.g-col.g-xs-12.g-md-6',
              z '.title', @model.l.get 'general.videos'
              z '.videos'
                _map $videos, ($video) ->
                  z $video
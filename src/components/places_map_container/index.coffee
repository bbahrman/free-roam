z = require 'zorium'
_map = require 'lodash/map'
_filter = require 'lodash/filter'
_zipWith = require 'lodash/zipWith'
_defaults = require 'lodash/defaults'
_find = require 'lodash/find'
_flatten = require 'lodash/flatten'
_reduce = require 'lodash/reduce'
_groupBy = require 'lodash/groupBy'
_sumBy = require 'lodash/sumBy'
_isEmpty = require 'lodash/isEmpty'
_uniq = require 'lodash/uniq'
RxBehaviorSubject = require('rxjs/BehaviorSubject').BehaviorSubject
RxReplaySubject = require('rxjs/ReplaySubject').ReplaySubject
RxObservable = require('rxjs/Observable').Observable
require 'rxjs/add/observable/combineLatest'
require 'rxjs/add/observable/of'

Checkbox = require '../checkbox'
Map = require '../map'
PlaceTooltip = require '../place_tooltip'
PlacesFilterBar = require '../places_filter_bar'
PlacesSearch = require '../places_search'
Fab = require '../fab'
TooltipPositioner = require '../tooltip_positioner'
Icon = require '../icon'
MapService = require '../../services/map'
colors = require '../../colors'
config = require '../../config'

if window?
  require './index.styl'

module.exports = class PlacesMapContainer
  constructor: (options) ->
    {@model, @router, isShell, @trip, @dataTypes, showScale, mapBoundsStreams,
      @persistentCookiePrefix, @addPlaces, @optionalLayers, @isSearchHidden,
      @limit, @sort, defaultOpacity, @currentDataType, initialCenter, center,
      initialZoom, zoom} = options

    mapBoundsStreams ?= new RxReplaySubject 1
    @sort ?= new RxBehaviorSubject undefined
    @limit ?= new RxBehaviorSubject null
    center ?= new RxBehaviorSubject null
    zoom ?= new RxBehaviorSubject null
    @currentDataType ?= new RxBehaviorSubject @dataTypes[0].dataType

    @persistentCookiePrefix ?= 'default'
    @addPlaces ?= RxObservable.of []

    zoomCookie = "#{@persistentCookiePrefix}_zoom"
    initialZoom ?= @model.cookie.get zoomCookie
    if initialZoom is 'undefined'
      initialZoom = undefined
    centerCookie = "#{@persistentCookiePrefix}_center"
    initialCenter ?= try
      JSON.parse @model.cookie.get centerCookie
    catch
      undefined

    @currentMapBounds = new RxBehaviorSubject null

    @isFilterTypesVisible = new RxBehaviorSubject false
    @isLegendVisible = new RxBehaviorSubject false

    @dataTypesStream = @getDataTypesStreams @dataTypes

    @isTripFilterEnabled = new RxBehaviorSubject Boolean @trip
    route = @trip?.map (trip) ->
      trip?.route

    @filterTypesStream = @getFilterTypesStream().publishReplay(1).refCount()
    placesStream = @getPlacesStream()
    placesWithCounts = RxObservable.combineLatest(
      @addPlaces, placesStream, (vals...) -> vals
    ).map ([addPlaces, {places, visible, total}]) ->
      if places
        places = addPlaces.concat places
      else
        places = addPlaces

      {places, visible, total}
    .share() # otherwise map setsData twice (subscribe called twice)

    places = placesWithCounts
            .map ({places}) -> places
    counts = placesWithCounts.map ({visible, total}) -> {visible, total}

    placesAndIsLegendVisible = RxObservable.combineLatest(
      places, @isLegendVisible, (vals...) -> vals
    )

    @place = new RxBehaviorSubject null
    @placePosition = new RxBehaviorSubject null
    @mapSize = new RxBehaviorSubject null
    @$fab = new Fab()
    @$layersIcon = new Icon()
    @$tooltip = new TooltipPositioner {
      @model
      key: 'mapLayers'
      offset:
        left: 60
    }

    persistentCookie = "#{@persistentCookiePrefix}_savedLayers"
    layersVisible = try
      JSON.parse @model.cookie.get persistentCookie
    catch
      []
    layersVisible or= []
    initialLayers = _map layersVisible, (layerId) =>
      optionalLayer = _find @optionalLayers, (optionalLayer) ->
        optionalLayer.layer.id is layerId

    @$map = new Map {
      @model, @router, places, @setFilterByField, showScale
      @place, @placePosition, @mapSize, mapBoundsStreams, @currentMapBounds
      defaultOpacity, initialCenter, center, initialZoom,  zoom,
      initialLayers, route
    }
    @$placeTooltip = new PlaceTooltip {
      @model, @router, @place, position: @placePosition, @mapSize
    }
    @$placesSearch = new PlacesSearch {
      @model, @router
      onclick: (location) ->
        if location.bbox and location.bbox[0] isnt location.bbox[2]
          mapBoundsStreams.next RxObservable.of {
            x1: location.bbox[0]
            y1: location.bbox[1]
            x2: location.bbox[2]
            y2: location.bbox[3]
          }
        else
          center.next [
            location.location.lon
            location.location.lat
          ]
          zoom.next 9
    }
    @$placesFilterBar = new PlacesFilterBar {
      @model, @isFilterTypesVisible, @currentDataType
      @trip, @isTripFilterEnabled
    }

    @state = z.state
      isShell: isShell
      filterTypes: @filterTypesStream
      dataTypes: @dataTypesStream
      visibleDataTypes: @dataTypesStream.map (dataTypes) ->
        _filter dataTypes, 'isChecked'
      currentDataType: @currentDataType
      place: @place
      icons: placesAndIsLegendVisible.map ([places, isLegendVisible]) ->
        if isLegendVisible
          _filter _uniq _map places, 'icon'
      counts: counts
      isLayersPickerVisible: false
      isLegendVisible: @isLegendVisible
      isFilterTypesVisible: @isFilterTypesVisible
      layersVisible: layersVisible

  afterMount: =>
    @disposable = @currentMapBounds.subscribe ({zoom, center} = {}) =>
      zoomCookie = "#{@persistentCookiePrefix}_zoom"
      @model.cookie.set zoomCookie, JSON.stringify zoom
      centerCookie = "#{@persistentCookiePrefix}_center"
      @model.cookie.set centerCookie, JSON.stringify center

  beforeUnmount: =>
    @disposable?.unsubscribe()
    @place.next null

  getDataTypesStreams: (dataTypes) =>
    persistentCookie = "#{@persistentCookiePrefix}_savedDataTypes"
    savedDataTypes = try
      JSON.parse @model.cookie.get persistentCookie
    catch
      {}

    dataTypes = _map dataTypes, (options) ->
      {dataType, onclick, filters, defaultValue, isCheckedSubject} = options
      savedValue = savedDataTypes[dataType]
      isCheckedSubject ?= new RxBehaviorSubject(
        if savedValue? then savedValue else defaultValue
      )
      {
        dataType: dataType
        filters: filters
        onclick: onclick
        isCheckedSubject: isCheckedSubject
        $checkbox: new Checkbox {value: isCheckedSubject}
      }

    RxObservable.combineLatest(
      _map dataTypes, 'isCheckedSubject'
      (vals...) -> vals
    )
    .map (values) =>
      dataTypesWithValue = _zipWith dataTypes, values, (dataType, isChecked) ->
        _defaults {isChecked}, dataType

      # set cookies to persist filters
      savedDataTypes = _reduce dataTypesWithValue, (obj, dataType) ->
        {dataType, isChecked} = dataType
        if isChecked?
          obj[dataType] = isChecked
        obj
      , {}
      @model.cookie.set persistentCookie, JSON.stringify savedDataTypes

      # if unchecking data type, set a new current
      {currentDataType} = @state.getValue()
      unless dataTypesWithValue[currentDataType]?.isChecked
        @currentDataType.next _find(dataTypesWithValue, 'isChecked')?.dataType

      dataTypesWithValue

  getFilterTypesStream: =>
    persistentCookie = "#{@persistentCookiePrefix}_savedFilters"
    savedFilters = try
      JSON.parse @model.cookie.get persistentCookie
    catch
      {}
    filters = _flatten _map @dataTypes, ({dataType, filters}) ->
      _map filters, (filter) ->
        if filter.type is 'booleanArray'
          savedValueKey = "#{dataType}.#{filter.field}.#{filter.arrayValue}"
        else
          savedValueKey = "#{dataType}.#{filter.field}"
        savedValue = savedFilters[savedValueKey]
        _defaults {
          dataType: dataType
          valueSubject: new RxBehaviorSubject(
            if savedValue? then savedValue else filter.defaultValue
          )
        }, filter

    if _isEmpty filters
      return RxObservable.of {}

    RxObservable.combineLatest(
      _map filters, 'valueSubject'
      (vals...) -> vals
    )
    .map (values) =>
      filtersWithValue = _zipWith filters, values, (filter, value) ->
        _defaults {value}, filter

      # set cookie to persist filters
      savedFilters = _reduce filtersWithValue, (obj, filter) ->
        {dataType, field, value, type, arrayValue} = filter
        if value? and type is 'booleanArray'
          obj["#{dataType}.#{field}.#{arrayValue}"] = value
        else if value?
          obj["#{dataType}.#{field}"] = value
        obj
      , {}
      @model.cookie.set persistentCookie, JSON.stringify savedFilters

      _groupBy filtersWithValue, 'dataType'

  getPlacesStream: =>
    unless window?
      return RxObservable.of []

    streamValues = RxObservable.combineLatest(
      @filterTypesStream, @currentMapBounds, @dataTypesStream
      @sort, @limit, @isTripFilterEnabled, @trip or RxObservable.of null
      (vals...) -> vals
    )
    streamValues.switchMap (response) =>
      [
        filterTypes, currentMapBounds, dataTypes, sort, limit,
        isTripFilterEnabled, trip
      ] = response

      boundsTooSmall = not currentMapBounds or Math.abs(
        currentMapBounds.bounds._ne.lat - currentMapBounds.bounds._sw.lat
      ) < 0.001

      if boundsTooSmall
        return RxObservable.of []

      RxObservable.combineLatest.apply null, _map dataTypes, ({dataType, isChecked}) =>
        unless isChecked
          return RxObservable.of []
        filters = filterTypes[dataType]
        queryFilter = MapService.getESQueryFromFilters(
          filters, currentMapBounds?.bounds
        )

        @model[dataType].search {
          limit: limit
          sort: sort
          tripId: if isTripFilterEnabled then trip?.id
          query:
            bool:
              filter: queryFilter
        }
      .map (responses) ->
        # visible = _sumBy responses, ({places}) -> places?.length
        total = _sumBy responses, 'total'
        places = _filter _map responses, 'places'
        places = _flatten places
        {
          visible: places.length
          total: total
          places: places
        }


  toggleLayer: (optionalLayer, index) =>
    {source, sourceId, layer, insertBeneathLabels} = optionalLayer
    {layersVisible} = @state.getValue()

    isVisible = index isnt -1

    if isVisible
      layersVisible.splice index, 1
    else
      ga? 'send', 'event', 'map', 'showLayer', layer.id
      layersVisible.push layer.id
    @state.set {layersVisible}

    persistentCookie = "#{@persistentCookiePrefix}_savedLayers"
    @model.cookie.set persistentCookie, JSON.stringify layersVisible

    @$map.toggleLayer layer, {
      insertBeneathLabels
      source: source
      sourceId: sourceId
    }


  render: =>
    {isShell, filterTypes, dataTypes, currentDataType, place, layersVisible,
      counts, visibleDataTypes, isFilterTypesVisible, isLegendVisible, icons,
      isLayersPickerVisible} = @state.getValue()

    isCountsBarVisbile = counts?.visible < counts?.total

    z '.z-places-map-container', {
      className: z.classKebab {isShell}
      onclick: =>
        if isLayersPickerVisible or isFilterTypesVisible or isLegendVisible
          @state.set isLayersPickerVisible: false
          @isLegendVisible.next false
          @isFilterTypesVisible.next false
    },
      [
        unless @isSearchHidden
          z '.search',
            z @$placesSearch, {dataTypes}
            z @$placesFilterBar, {
              dataTypes, currentDataType, filterTypes, visibleDataTypes
              @trip, @isTripFilterEnabled
            }
        z '.counts-bar', {
          className: z.classKebab {isVisible: isCountsBarVisbile}
        },
          @model.l.get 'placesMapContainer.countsBar', {
            replacements:
              visible: counts?.visible
              total: counts?.total
          }

        z '.map',
          z @$map
          z @$placeTooltip

          z '.legend-fab', {
            onclick: =>
              @isLegendVisible.next true
          },
            @model.l.get 'placesMapContainer.legend'

          z '.legend', {
            className: z.classKebab {isVisible: isLegendVisible}
          },
            _map icons, (icon) =>
              z '.item',
                z 'img.icon',
                  src: if isLegendVisible \
                       then "#{config.CDN_URL}/maps/sprite_svgs/#{icon}.svg"
                z '.name', @model.l.get "mapLegend.#{icon}"

          unless _isEmpty @optionalLayers
            z '.layers-fab',
              z @$fab,
                colors:
                  c500: colors.$tertiary100
                  ripple: colors.$bgText70
                $icon: z @$layersIcon, {
                  icon: 'layers'
                  isTouchTarget: false
                  color: colors.$bgText54
                }
                isImmediate: true
                onclick: =>
                  ga? 'send', 'event', 'map', 'showLayers'
                  @state.set isLayersPickerVisible: true
                  @$tooltip.close()

              z @$tooltip


          z '.layers', {
            className: z.classKebab {isVisible: isLayersPickerVisible}
            onclick: (e) ->
              e?.stopPropagation()
          },
            z '.content',
              z '.title', @model.l.get 'placesMapContainer.layers'
              z '.layer-icons',
                z '.g-grid',
                  z '.g-cols',
                    if isLayersPickerVisible
                      _map @optionalLayers, (optionalLayer) =>
                        {name, layer} = optionalLayer
                        index = layersVisible.indexOf(layer.id)
                        isVisible = index isnt -1
                        z ".layer-icon.#{layer.id}.g-col.g-xs-4.g-md-4", {
                          className: z.classKebab {isVisible}
                          onclick: =>
                            @toggleLayer optionalLayer, index
                        },
                          z '.icon'
                          z '.name', name
      ]

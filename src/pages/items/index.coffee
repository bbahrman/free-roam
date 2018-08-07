z = require 'zorium'
_map = require 'lodash/map'
_find = require 'lodash/find'

AppBar = require '../../components/app_bar'
ButtonBack = require '../../components/button_back'
Items = require '../../components/items'
Base = require '..//base'
colors = require '../../colors'
config = require '../../config'

if window?
  require './index.styl'

module.exports = class ItemsPage extends Base
  hideDrawer: true

  constructor: ({@model, @router, requests, serverData, group}) ->
    category = @clearOnUnmount requests.map ({route}) =>
      route.params.category

    @$appBar = new AppBar {@model}
    @$buttonBack = new ButtonBack {@model, @router}
    @$items = new Items {@model, @router, category}

    @state = z.state
      me: @model.user.getMe()
      category: category.switchMap (category) =>
        @model.category.getAll()
        .map (categories) ->
          _find categories, {id: category}
      windowSize: @model.window.getSize()

  getMeta: ->
    {
      title: "How to decide what to buy for your RV"
    }

  render: =>
    {me, windowSize, category} = @state.getValue()

    z '.p-items', {
      style:
        height: "#{windowSize.height}px"
    },
      z @$appBar, {
        title: category?.name
        style: 'primary'
        $topLeftButton: z @$buttonBack, {color: colors.$header500Icon}
        $topRightButton:
          z '.p-group-home_top-right',
            z @$notificationsIcon,
              icon: 'notifications'
              color: colors.$header500Icon
              onclick: =>
                @overlay$.next @$notificationsOverlay
            z @$settingsIcon,
              icon: 'settings'
              color: colors.$header500Icon
              onclick: =>
                @overlay$.next new SetLanguageDialog {
                  @model, @router, @overlay$, @group
                }
      }
      @$items

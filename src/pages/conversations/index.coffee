z = require 'zorium'

AppBar = require '../../components/app_bar'
ButtonMenu = require '../../components/button_menu'
Conversations = require '../../components/conversations'
colors = require '../../colors'

if window?
  require './index.styl'

module.exports = class ConversationsPage
  constructor: ({@model, requests, @router, serverData, group}) ->
    @$appBar = new AppBar {@model}
    @$buttonMenu = new ButtonMenu {@model, @router}
    @$conversations = new Conversations {@model, @router}

  getMeta: =>
    {
      title: @model.l.get 'drawer.privateMessages'
    }

  render: =>
    z '.p-conversations',
      z @$appBar,
        $topLeftButton: z @$buttonMenu, {color: colors.$header500Icon}
        title: @model.l.get 'drawer.privateMessages'
      @$conversations

z = require 'zorium'

NewAmenity = require '../../components/new_amenity'

if window?
  require './index.styl'

module.exports = class NewAmenityPage
  hideDrawer: true

  constructor: ({@model, requests, @router, serverData}) ->
    center = requests.map ({req}) ->
      center = req.query.center
      if center
        coordinates = center.split ','
        {lat: coordinates[0], lng: coordinates[1]}

    @$newAmenity = new NewAmenity {@model, @router, center}

  getMeta: =>
    {
      title: @model.l.get 'newPlacePage.title', {
        replacements:
          prettyType: 'Amenity'
      }
    }

  render: =>
    z '.p-new-amenity',
      @$newAmenity

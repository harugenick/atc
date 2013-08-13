# Since modals are not visible and are not necessarily tied to a view/redion
# provide one registry for all the modals.
#
# The initial use cases were:
# - `enable-dnd` does not have specific UI except for a modal that prompts whether to copy, link, or move.
# - `gh-book/auth` only needs to pop up modals when asking for user credentials
#
# **TODO:** Make this a Singleton layout instead of a View.
# The Layout already performs many of these operations but it is not justified yet
# because there is only one user of it (enable-dnd)
define ['marionette'], (Marionette) ->
  # Singleton that returns an array of Modals and a way to add/remove them

  viewMap = {}
  modalView = new class ModalView extends Marionette.View

  # Detach all modals if this view is closed
  modalView.on 'close', () ->
    for key, view in viewMap
      view.close()

  return new class Modals

    # There are several slots (keyed by `key`) that can contain a ModalView
    # The reason for this is that a DnD drop event needs to pop open a view
    # that may have the title rendered in the view.
    #
    # Because of that, the `enable-dnd.coffee` needs to replace the view and
    # `allViews` needs to unbind the view from listening to updates from the model
    add: (key, view) ->
      # Close the previous modal so listeners are detached
      viewMap[key]?.close()
      # Remove it from the DOM too
      viewMap[key]?.$el.remove()

      viewMap[key] = view
      modalView.$el.append(view.$el)
      view.render()

    getView: () -> modalView


  # return new class ModalLayout extends Marionette.Layout
  #   regions:
  #     dndCopyLinkMove: '#dnd-copy-link-move'


define [
  'jquery'
  'underscore'
  'marionette'
  'aloha'
  'cs!collections/content' # Only needed for the Modal
  'cs!collections/media-types' # Only needed for the Modal
  'cs!views/all-modals' # Only needed for the Modal
  'hbs!templates/workspace/dnd-handle'
  'hbs!templates/workspace/dnd-copy-link-move' # Only needed for the Modal
], ($, _, Marionette, Aloha, allContent, mediaTypes, allModals, dndHandleTemplate, copyLinkMoveTemplate) ->

  class ModalView extends Marionette.ItemView
    onRender: () ->
      $model = @$el.children()
      throw new Error 'BUG! More than one modal in a template!' if $model.length != 1
      $model.modal('show')
      $model.on 'hide', () => @onHidden()

    onClose: () -> @$el.children().modal('hide')

    onHidden: () -> # Do nothing by default

  class CopyLinkMoveModal extends ModalView
    template: copyLinkMoveTemplate
    events:
      'click .ok': 'onOk'

    onOk: () ->
      # Disable the 'ok' button so it cannot be clicked multiple times
      @$el.find('.ok').addClass('disabled')

      operation = @$el.find('[name="operation"]:checked').val()
      @doStuff(operation)

    doStuff: (operation) ->
      throw new Error('BUG: This should be set during construction')


  # Drag and Drop Behavior
  # -------
  #
  # Several views allow content to be dragged around.
  # Each item that is draggable **must** contain 3 DOM attributes:
  #
  # - `data-content-id`:    The unique id of the piece of content (it can be a path)
  # - `data-media-type`:    The mime-type of the content being dragged
  # - `data-content-title`: A  human-readable title for the content
  #
  # In addition it may contain the following attributes:
  #
  # - `data-drag-operation="copy"`: Specifies the CSS to add a "+" when dragging
  #                                 hinting that the element will not be removed.
  #                                 (For example, content in a search result)
  #
  # Additionally, each draggable element should not contain any text children
  # so CSS can hide children and properly style the cloned element that is being dragged.
  enableContentDragging = (model, $content) ->
    throw 'BUG: $content MUST be an element with a data-media-type attribute' if not $content.is('[data-media-type]')

    $content.data('editor-model', model)
    $content.draggable
      addClasses: false
      revert: 'invalid'
      # Ensure the handle is on top (zindex) and not bound to be constrained inside a div visually
      appendTo: 'body'
      # Place the little handle right next to the mouse
      cursorAt:
        top: 0
        left: 0
      helper: (evt) ->
        title = model.get('title') or ''
        shortTitle = title.substring(0, 20)
        if title.length > 20 then shortTitle += '...'

        # If the content is a pointer to a piece of content (`BookTocNode`)
        # then use the actual content's mediaType
        mediaType = model.mediaType

        # Generate the handle div using a template
        handle = dndHandleTemplate
          id: model.id
          mediaType: mediaType
          title: title
          shortTitle: shortTitle

        return $(handle)


  # Defines drop zones based on `model.accepts()` media types
  # `onDrop` takes 2 arguments: `drag` and `drop`.
  enableDrop = (model, $content, accepts, onDrop) ->
    # Since we use jqueryui's draggable which is loaded when Aloha loads
    # delay until Aloha is finished loading
    Aloha.ready =>
      # Figure out which mediaTypes can be dropped onto each element
      validSelectors = _.map(accepts, (mediaType) -> "*[data-media-type=\"#{mediaType}\"]")
      validSelectors = validSelectors.join(',')

      if validSelectors
        $content.droppable
          greedy: true
          addClasses: false
          accept: validSelectors
          activeClass: 'editor-drop-zone-active'
          hoverClass: 'editor-drop-zone-hover'
          drop: (evt, ui) ->
            $drag = ui.draggable
            $drop = $(evt.target)

            # Find the model representing the id that was dragged
            drag = $drag.data 'editor-model'
            drop = $drop.data 'editor-model'


            # Extend the class so `onDrop` can be squirreled inside
            class SpecificCopyLinkMoveModal extends CopyLinkMoveModal
              # doStuff takes an operation argument:
              # - `link` (default): keep a reference in both places
              # - `copy` : Make a copy of the Model and refer to the copied model
              # - `move` : Put a reference in the drop location and remove the previous reference (if there was one)
              doStuff: (operation) ->
                switch operation
                  when 'link'
                    onDrop(drag, drop)
                    @close()
                  when 'copy'
                    drag.load()
                    .fail(()=> alert 'There was a problem loading the file so we could make a copy of it')
                    .done () =>
                      json = drag.toJSON()
                      json.mediaType ?= drag.mediaType # Set the mediaType just in case `.toJSON()` does not
                      json.title = "Copy of #{json.title}"
                      delete json.id
                      clone = allContent.model(json)
                      allContent.add(clone)

                      onDrop(clone, drop)
                      @close() # Wait until successfully loaded and dropped before closing

            # Add the dropModal
            # Delay the call so $.droppable has time to clean up before the DOM changes
            dropModal = new SpecificCopyLinkMoveModal {model:drag}
            # 'copy-link-move' is the "slot"
            allModals.add('copy-link-move', dropModal)

  return {
    enableContentDnD: (model, $content) ->
      # Since we use jqueryui's draggable which is loaded when Aloha loads
      # delay until Aloha is finished loading
      Aloha.ready =>
        enableContentDragging(model, $content)

      enableDrop model, $content, model.accept, (drag, drop) ->
        # If the model is already in the tree then remove it
        # If the model is in the same collection but at a different index then
        #   account for the model being removed

        drop.addChild drag

    # Enable drop zones after a node.
    # Used for tree reordering.
    #
    # This zone is based on the parent model's `accepts()` media types
    enableDropAfter: (model, parent, $content) ->
      throw 'BUG: model MUST have a parent' if not parent
      $content.data('editor-model', model)

      enableDrop model, $content, parent.accept, (drag, drop) ->
        index = parent.getChildren().indexOf(model)
        parent.addChild drag, index+1
  }

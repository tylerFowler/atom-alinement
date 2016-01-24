{ CompositeDisposable } = require 'atom'
R                       = require 'ramda'

module.exports = Alinement =
  subscriptions: null

  # match the left hand of an assignment, e.g. `let x`
  ## on the first bit, we don't want to try and align things that
  ## are in comments, though I suppose that's a philosophical question
  lefthandExpr: /(^[^\s*\#\s*\/].+)(?:=)/

  # match the right hand of the assignment, e.g. = require('somepak')
  ## does not work for golang's `:=` assignment operator, any regex
  ## suggestions are welcome
  righthandExpr: /\=[^\>\<].+$/

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'alinement:align-selection': => @alignSelection()

  deactivate: -> @subscriptions.dispose()

  padRight: (s, numSpaces) ->
    # +1 because the join only goes *between* elements
    R.concat s, (new Array(numSpaces + 1)).join(' ')

  # TODO: there's an interesting edge case on lines like: `x = y =\n`
  # where this will actually register an assignee of `x = y` and an assignment
  # of `= y =`, resulting in `x = y = y =` - obviously not desirable behavior
  # TODO: when a line is partially selected, extend the selection to
  # cover the whole line
  alignSelection: ->
    if editor = atom.workspace.getActiveTextEditor()
      # include the whole lines in the selection to avoid mangling things
      # in the middle
      editor.selectToBeginningOfLine()

      lines = editor.getSelectedText()
      .split '\n'
      .map (l) =>
        lineData = line: l

        leftMatch = l.match @lefthandExpr
        lineData.assignee =
          if leftMatch and leftMatch.length > 0
            R.last(leftMatch).trimRight()
          else null

        rightMatch = l.match @righthandExpr
        lineData.assignment =
          if rightMatch and rightMatch.length > 0
            rightMatch[0].trimLeft()
          else null

        return lineData

      console.log "Got line data", lines

      # if we have nothing to process just return
      return unless lines.length > 0

      # don't process just one line
      return unless lines.filter((l) -> l.assignee and l.assignment).length > 1

      maxAssigneeSize = Math.max.apply(
        null,
        lines
        .filter (l) -> l.assignee and l.assignment
        .map (l) -> l.assignee.length
      )

      paddedSelection = lines
      .map (l) =>
        unless l.assignee and l.assignment
          return l.line

        R.concat(
          @padRight(l.assignee, (maxAssigneeSize - l.assignee.length) + 1)
        )(
          l.assignment
        )
      .join('\n')

      editor.insertText(paddedSelection)

_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  getInitialState: ->
    currentVal = if @props.identity
      @formatIdentity @props.identity
    else
      ''
    active: false
    currentVal: currentVal
    results: []
    identity: @props.identity ? {}
    selectedIdentityId: ''

  componentDidMount: ->
    window.identityAutoComplete = @
    @history = {}
    @cache = []
    @socket = @props.getSocket 'identity-autocomplete'
    @socket.on 'data', (data) =>
      return unless data.identity?._id
      return console.log 'stahp' unless @isMounted()
      exists = _.find @cache, (identity) ->
        identity._id == data.identity._id
      @cache.push data.identity unless exists
      @updateResults()

  componentWillUnmount: ->
    @socket.off 'data'

  componentWillReceiveProps: (newProps) ->
    if newProps.identity
      formatted = @formatIdentity newProps.identity
      @setState
        identity: newProps.identity
        currentVal: formatted
    true

  formatIdentity: (identity) ->
    return '' unless identity?._id
    identity.fullName ? identity.nickName

  presentIdentity: (identity) ->
    return '' unless identity?._id
    name = identity.fullName ? identity.nickName
    platforms = identity.platform
    DOM.span null,
      name
      ' '
      DOM.em null, "(#{platforms.join ', '})"

  updateResults: (currentVal = @state.currentVal) ->
    val = currentVal.toLowerCase()
    pattern = /\b([a-z0-9\-]+)\b/gi
    words = []
    while match = pattern.exec val
      words.push match[1]
    matchPattern = _ words
      .map (word) ->
        "(\\b#{word.replace /([^a-z0-9])/gi, '\\$1'})"
      .value()
      .join '|'
    matcher = new RegExp matchPattern, 'g'
    matchers = _.map matchPattern.split('|'), (m) ->
      new RegExp m

    unless val.length > 0 and matchPattern?.length > 0
      return @setState
        results: []
        currentVal: currentVal

    omit = @props.omit ? []
    results = _ @cache
      .filter (identity) =>
        return false unless -1 == omit.indexOf identity._id
        allNames = [
          (identity.nickName ? '')
          (identity.fullName ? '')
          (identity.firstName ? '')
          (identity.lastName ? '')
        ].join ' '
        .replace /\s+/g, ' '
        .replace /(^\s+)|(\s+$)/g, ''
        .toLowerCase()
        return false unless allNames.length > 0
        matcher.test allNames
      .sortBy (identity) ->
        allNames = [
          (identity.nickName ? '')
          (identity.fullName ? '')
          (identity.firstName ? '')
          (identity.lastName ? '')
        ].join ' '
        .replace /\s+/, ' '
        .replace /(^\s+)|(\s+$)/, ''
        .toLowerCase()
        score = 0
        if identity?.attributes?.isFriend == true
          score += 100
        for m in matchers
          if m.test allNames
            score += 10
            score += m.toString().length
        -score
      .reduce (memo, identity) ->
        return memo unless -1 == memo.ids.indexOf identity._id
        memo.identities.push identity
        memo.ids = memo.ids.concat identity._id
        memo
      , {identities: [], ids: []}
      .identities
      .slice 0, 7

    @setState
      results: results
      currentVal: currentVal

  onChange: (e) ->
    keyword = e.target.value
    _keyword = keyword?.toLowerCase()

    if _keyword?.length > 0 and !@history[_keyword]
      @socket.write
        query: _keyword
      @history[_keyword] = true

    @updateResults keyword

  onFocus: (e) ->
    e.target.selectionStart = 0
    e.target.selectionEnd = e.target.value.length
    @setState
      active: true
      currentVal: e.target.value
      results: []

  onBlur: ->
    setTimeout =>
      return unless @isMounted()
      @setState
        active: false
        currentVal: @formatIdentity @state.identity
    , 100

  selectIdentity: (identity) ->
    (e) =>
      e.preventDefault()
      return unless @props.onSelect
      @props.onSelect identity

  selectById: (id) ->
    identity = _.find @cache, (identity) ->
      identity._id == id
    if identity
      @props.onSelect identity
      @setState
        currentVal: @formatIdentity identity

  onKeyPress: (e) ->
    TAB = 9
    ENTER = 13
    UP = 38
    DOWN = 40
    if e.keyCode == UP or e.keyCode == DOWN
      dir = if e.keyCode == UP then -1 else 1

      e.preventDefault()
      index = _.findIndex @state.results, (identity) =>
        identity._id == @state.selectedIdentityId
      if !index? or index == -1
        @setState
          selectedIdentityId: if dir == 1
            @state.results[0]?._id
          else
            @state.results[@state.results?.length - 1]?._id
        return
      index += dir
      if @state.results[index]?._id
        @setState
          selectedIdentityId: @state.results[index]._id
      return
    if e.keyCode == ENTER or e.keyCode == TAB
      e.preventDefault()
      @selectById @state.selectedIdentityId

  render: ->
    exactMatch = =>
      _.find @state.results, (identity) =>
        @state.currentVal == @formatIdentity identity

    DOM.span
      className: 'identity-autocomplete'
    ,
      DOM.input
        value: @state.currentVal
        placeholder: 'autocomplete'
        onChange: @onChange
        onFocus: @onFocus
        onBlur: @onBlur
        onKeyDown: @onKeyPress
      if @state.active and @state.results.length > 0 and !exactMatch()
        DOM.div
          className: 'identity-autocomplete-results'
        ,
          _.map @state.results, (identity) =>
            DOM.a
              key: identity._id
              href: '#'
              onClick: @selectIdentity identity
              className: if @state.selectedIdentityId == identity._id
                'identity-selected'
              else
                ''
            , @presentIdentity identity
      else
        null

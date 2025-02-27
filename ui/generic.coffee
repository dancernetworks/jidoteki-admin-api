'use strict'
apiServer = if window.location.origin?
  window.location.origin
else
  "#{window.location.protocol}//#{window.location.hostname}#{(if window.location.port? then ':' + window.location.port else '')}"

### generic functions ###

putToken = (sha256) ->
  if $('#login-remember').is(':checked')
    date    = new Date()
    oneDay  = (24 * 60 * 60 * 1000)
    days    = 30
    date.setTime(+ date + (days * oneDay))

    document.cookie = "jidoteki-admin-api-token=#{sha256}; expires=#{date.toGMTString()}; path=/; secure;"
  else
    document.cookie = "jidoteki-admin-api-token=#{sha256}; path=/; secure;"

getToken = ->
  (document.cookie.match('(^|; )jidoteki-admin-api-token=([^;]*)')||0)[2]

clearToken = ->
  document.cookie = 'jidoteki-admin-api-token=; path=/; secure; '

capitalize = (string) ->
  string.charAt(0).toUpperCase() + string.slice(1)

getSha256 = (string) ->
  md = forge.md.sha256.create()
  md.update string

  md.digest().toHex()

getHmac = (string, key) ->
  hmac = forge.hmac.create()
  hmac.start 'sha256', key
  hmac.update string

  hmac.digest().toHex()

fetchData = (endpoint, callback) ->
  sha256 = getToken()
  if sha256?
    hmac = getHmac "GET#{endpoint}", sha256

    $.get "#{apiServer}#{endpoint}?hash=#{hmac}"

    .done (response) ->
      callback null, response

    .fail (err) ->
      callback err
  else
    callback new Error "Missing or invalid API token"

fetchFile = (endpoint, callback) ->
  sha256 = getToken()
  if sha256?
    hmac = getHmac "GET#{endpoint}", sha256
    $(location).attr 'href', "#{apiServer}#{endpoint}?hash=#{hmac}"
  else
    callback new Error "Missing or invalid API token"

putFile = (msg, endpoint, file, callback) ->
  sha256 = getToken()
  if sha256?
    hmac = getHmac "POST#{endpoint}", sha256

    $(".jido-page-content-#{msg} .progress .progress-bar").removeClass 'bg-danger'
    $(".jido-page-content-#{msg} .progress .progress-bar").removeClass 'bg-primary'
    $(".jido-page-content-#{msg} .progress .progress-bar").addClass 'bg-striped'
    $(".jido-page-content-#{msg} .progress .progress-bar").attr 'bg-striped', 33
    $(".jido-page-content-#{msg} .progress .progress-bar").attr 'aria-valuenow', 33
    $(".jido-page-content-#{msg} .progress .progress-bar").html '....uploading, please wait'
    $(".jido-page-content-#{msg} .progress .progress-bar").attr 'style', 'width: 33%'
    $(".jido-page-content-#{msg} .progress").show()

    $.ajax
      url : "#{apiServer}#{endpoint}?hash=#{hmac}"
      type: "POST"
      data : file
      processData: false
      contentType: false
      success: (response, status, jqXHR) ->
        runningUpload msg
        callback null, response
      error: (jqXHR, status, err) ->
        failedUpload msg, 'upload failed'
        callback new Error(err), jqXHR
  else
    callback new Error "Missing or invalid API token"

runningUpload = (msg) ->
  $(".jido-page-content-#{msg} .progress").show()
  $(".jido-page-content-#{msg} .progress .progress-bar").addClass 'bg-primary'
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'bg-striped', 66
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'aria-valuenow', 66
  $(".jido-page-content-#{msg} .progress .progress-bar").html '...updating'
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'style', 'width: 66%'

successUpload = (msg) ->
  $(".jido-page-content-#{msg} .progress .progress-bar").removeClass 'bg-striped'
  $(".jido-page-content-#{msg} .progress .progress-bar").addClass 'bg-success'
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'aria-valuenow', 100
  $(".jido-page-content-#{msg} .progress .progress-bar").html 'done'
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'style', 'width: 100%'
  $(".#{msg}-form").show()
  $(".#{msg}-alert").hide()

failedUpload = (msg, message) ->
  $(".jido-page-content-#{msg} .progress .progress-bar").removeClass 'bg-striped'
  $(".jido-page-content-#{msg} .progress .progress-bar").addClass 'bg-danger'
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'aria-valuenow', 100
  $(".jido-page-content-#{msg} .progress .progress-bar").html validator.escape(message)
  $(".jido-page-content-#{msg} .progress .progress-bar").attr 'style', 'width: 100%'
  $(".#{msg}-form").show()
  $(".#{msg}-alert").hide()

getStatus = (msg, callback) ->
  fetchData "/api/v1/#{apiType}/#{msg}", (err, result) ->
    if err
      callback new Error(err)
    else
      if typeof result.status is 'object' then status = "" else status = validator.escape(result.status)
      $(".jido-data-#{msg}-status").show()
      $(".jido-data-#{msg}-status").html status
      if result.log
        $(".jido-data-#{msg}-log").html(if typeof result.log is 'object' then "No log file found" else validator.escape(result.log).replace(/\\n/g,'<br/>'))

      label = switch status
        when "failed"     then "badge-danger"
        when "success"    then "badge-success"
        when "running"    then "badge-primary"
        else
          $(".jido-data-#{msg}-status").html "waiting for #{msg}"
          "badge-light"

      if status == 'failed'
        $(".jido-page-content-#{msg} .alert.jido-panel").addClass "alert-danger"
        $(".jido-page-content-#{msg} .jido-page-content-#{msg}-panel").attr 'style', 'background-color: none'
      else
        $(".jido-page-content-#{msg} .alert.jido-panel").removeClass "alert-danger"
        $(".jido-page-content-#{msg} .jido-page-content-#{msg}-panel").attr 'style', 'background-color: #EEEEEE'

      if result['error-code'] and result['error-message'] and status == 'failed'
        $(".jido-data-#{msg}-status-error").show()
        $(".jido-data-#{msg}-status-error-message").html "#{validator.escape(result['error-code'])}: #{validator.escape(result['error-message'])}"
      else
        $(".jido-data-#{msg}-status-error").hide()
        $(".jido-data-#{msg}-status-error-message").html ''

      $(".jido-data-#{msg}-status").removeClass("badge-danger")
      $(".jido-data-#{msg}-status").removeClass("badge-success")
      $(".jido-data-#{msg}-status").removeClass("badge-light")
      $(".jido-data-#{msg}-status").addClass(label)

      callback result

pollStatus = (msg) ->
  $(".#{msg}-form").hide()
  $(".#{msg}-alert").show()
  $(".jido-data-#{msg}-status").removeClass("badge-danger")
  $(".jido-data-#{msg}-status").removeClass("badge-success")
  $(".jido-data-#{msg}-status").addClass("badge-light")

  interval = setInterval () ->
    getStatus msg, (result) ->
      if result.status is "failed"
        clearInterval interval
        failedUpload msg, 'failed'
      else if result.status is "success"
        clearInterval interval
        successUpload msg
        loadBackup() if msg is "backup"
      else if result.status is "running"
        runningUpload msg
  , 1000

redirectUrl = (newUrl) ->
  interval = setInterval () ->
    clearInterval interval
    $(location).attr 'href', newUrl
  , 5000

authenticate = (callback) ->
  fetchData "/api/v1/admin/version", (err, result) ->
    if err
      clearToken()
      if typeof err.responseJSON is 'object' and typeof err.responseJSON['First-Run'] is 'boolean'
        # hide the 'API Token Setup' button
        $('#new-token').hide()
      callback err
    else
      callback null

reloadHealth = () ->
  fetchData "/api/v1/admin/health", (err, result) ->
    unless err
      cpudanger   = if result['cpu']['cpu5min'] >= result['cpu']['num'] then 'jido-health-danger' else ''
      diskdanger  = if result['disk']['percentage'] >= 98 then 'jido-health-danger' else ''
      memdanger   = if result['memory']['percentage'] >= 90 then 'jido-health-danger' else ''

      $('#jido-health-bar').empty()
      $('#jido-health-bar').append "<li class=\"#{cpudanger}\">cpu #{result['cpu']['load']} (#{result['cpu']['num']} cores)</li>"
      $('#jido-health-bar').append "<li class=\"#{diskdanger}\">disk #{result['disk']['used']} of #{result['disk']['total']} (#{result['disk']['percentage']}%)</li>"
      $('#jido-health-bar').append "<li class=\"#{memdanger}\">memory #{result['memory']['used']} of #{result['memory']['total']} (#{result['memory']['percentage']}%)</li>"

reloadEndpoints = () ->
  fetchData "/api/v1/admin/endpoints", (err, result) ->
    unless err
      # display the menu button if the endpoint is enabled
      for value in apiEndpoints
        if "/api/v1/admin/#{value}" in result.endpoints
          $("#jido-button-#{value}").show()

### generic content functions ###

loadFirstrun = ->
  $('#jido-page-login').hide()
  $('.jido-page-content').hide()
  $('#jido-page-navbar').hide()
  $('#jido-page-firstrun').show()
  $('.jido-page-content-firstrun .jido-panel-network').show()
  $('.token-form .token-setuptoken-label').focus()

  $('.token-form input.form-control').val '' # reset all token input fields

loadToken = ->
  $('#jido-page-login').hide()
  $('.jido-page-content').hide()
  $('#jido-page-navbar .navbar-nav li').removeClass('active')
  $('#jido-button-token').addClass('active')
  $('#jido-page-navbar').show()
  $('#jido-page-token').show()
  $('.jido-page-content-token .jido-panel-network').show()
  $('.token-form .token-token1-label').focus()
  $('.token-form input.form-control').val '' # reset all token input fields
  
  fetchData "/api/v1/admin/installer", (err, result) ->
      unless err
        if result.installer == 'iso'
            $('#jido-button-update').hide()
  reloadEndpoints()

loadSetup = ->
  $('#jido-page-login').hide()
  $('.jido-page-content').hide()
  $('#jido-page-navbar').hide()
  $('#jido-page-token').show()
  $('.jido-page-content-token .jido-panel-network').show()
  $('.token-form .token-token1-label').focus()

  $('.token-form input.form-control').val '' # reset all token input fields

loadLogin = ->
  $('.jido-page-content').hide()
  $('#jido-page-navbar').hide()
  $('#jido-page-login').show()
  $('#login-password').focus()

### generic onclick listeners ###

logoutButtonListener = ->
  $('#jido-button-logout').click ->
    clearToken()
    location.reload() # reload the page on logout

loginButtonListener = ->
  $('#jido-button-login').click ->
    pass = $('#login-password').val()
    sha256 = getSha256 pass if pass.length >= 0 && pass.length <= 255
    if sha256?
      putToken sha256
      authenticate (err) ->
        if err
          $('#invalid-token').show()
          $('#login-password').focus()
        else
          $('#login-password').val ''
          $('#invalid-token').hide()
          loadHome()
    else
      $('#invalid-token').show()
      $('#login-password').focus()

newTokenButtonListener = ->
  $('#new-token').click ->
    loadSetup()

tokenButtonListener = ->
  $('#jido-button-token-upload').click ->

    $('.token-form .token-token1-label').parent().removeClass 'has-error'
    $('.token-form .token-token2-label').parent().removeClass 'has-error'

    pass1 = $('#token1-input').val()
    pass2 = $('#token2-input').val()

    unless pass1
      $('.token-form .token-token1-label').parent().addClass 'has-error'
      $('.token-form .token-token1-label').html 'API Token (required)'
      $('.token-form .token-token1-label').focus()
      return

    passwordStrength = zxcvbn(pass1, user_inputs=['password12', 'password@1', 'password@12', 'password@123'])

    unless pass1.length >= 8 && pass1.length <= 255
      $(".token-alert").html 'Invalid API Token. Must be between 8 and 255 characters'
      $(".token-alert").show()
      $('.token-form .token-token1-label').parent().addClass 'has-error'
      $('.token-form .token-token1-label').html 'API Token (required)'
      $('.token-form .token-token1-label').focus()
      return

    unless passwordStrength.score >= 2
      $(".token-alert").html "API Token is too weak. #{passwordStrength.feedback.warning}"
      $(".token-alert").show()
      $('.token-form .token-token1-label').parent().addClass 'has-error'
      $('.token-form .token-token1-label').html 'API Token (required)'
      $('.token-form .token-token1-label').focus()
      return

    unless pass2
      $('.token-form .token-token2-label').parent().addClass 'has-error'
      $('.token-form .token-token2-label').html 'Confirm API Token (required)'
      $('.token-form .token-token2-label').focus()
      return

    unless pass1 is pass2
      $('.token-alert').html 'API Token mismatch. Please verify the API Token.'
      $(".token-alert").show()
      return

    sha256 = getSha256 pass1

    formData = new FormData()
    formData.append 'newtoken', pass1

    if formData
      $('.jido-page-content-token .jido-panel').show()
      putFile 'token', '/api/v1/admin/setup', formData, (err, result) ->
        if err
          $('.jido-data-token-status').html 'failed'
          $('.jido-data-token-status').removeClass 'badge-danger'
          $('.jido-data-token-status').removeClass 'badge-success'
          $('.jido-data-token-status').removeClass 'badge-light'
          $('.jido-data-token-status').addClass 'badge-danger'

          failedUpload 'token'
        else
          $('.jido-data-token-status').html 'changed'
          $('.jido-data-token-status').removeClass 'badge-danger'
          $('.jido-data-token-status').removeClass 'badge-success'
          $('.jido-data-token-status').removeClass 'badge-light'
          $('.jido-data-token-status').addClass 'badge-success'
          $(".token-alert").hide()

          putToken sha256
          successUpload 'token'
          $('#token1-input').val ''
          $('#token2-input').val ''
          $('.jido-page-content-token .jido-panel-network').hide()
          loadToken()

setuptokenButtonListener = ->
  $('#jido-button-firstrun-upload').click ->

    $('.token-form .token-token1-label').parent().removeClass 'has-error'
    $('.token-form .token-token2-label').parent().removeClass 'has-error'

    setup = $('#setuptoken-input').val()
    pass1 = $('#setuptoken1-input').val()
    pass2 = $('#setuptoken2-input').val()

    unless setup
      $('.token-form .token-setuptoken-label').parent().addClass 'has-error'
      $('.token-form .token-setuptoken-label').html 'Setup Token (required)'
      $('.token-form .token-setuptoken-label').focus()
      return

    unless pass1
      $('.token-form .token-token1-label').parent().addClass 'has-error'
      $('.token-form .token-token1-label').html 'API Token (required)'
      $('.token-form .token-token1-label').focus()
      return

    passwordStrength = zxcvbn(pass1, user_inputs=['password12', 'password@1', 'password@12', 'password@123'])

    unless pass1.length > 8 && pass1.length <= 255
      $(".token-alert").html 'Invalid API Token. Must be between 8 and 255 characters'
      $(".token-alert").show()
      $('.token-form .token-token1-label').parent().addClass 'has-error'
      $('.token-form .token-token1-label').html 'API Token (required)'
      $('.token-form .token-token1-label').focus()
      return

    unless passwordStrength.score >= 2
      $(".token-alert").html "API Token is too weak. #{passwordStrength.feedback.warning}"
      $(".token-alert").show()
      $('.token-form .token-token1-label').parent().addClass 'has-error'
      $('.token-form .token-token1-label').html 'API Token (required)'
      $('.token-form .token-token1-label').focus()
      return

    unless pass2
      $('.token-form .token-token2-label').parent().addClass 'has-error'
      $('.token-form .token-token2-label').html 'Confirm API Token (required)'
      $('.token-form .token-token2-label').focus()
      return

    unless pass1 is pass2
      $('.token-alert').html 'API Token mismatch. Please verify the API Token.'
      $(".token-alert").show()
      return

    sha256 = getSha256 pass1

    formData = new FormData()
    formData.append 'newtoken', pass1

    if formData
      setupsha256 = getSha256 setup
      putToken setupsha256
      $('.jido-page-content-firstrun .jido-panel').show()
      putFile 'firstrun', '/api/v1/admin/setup', formData, (err, result) ->
        if err
          $('.jido-data-firstrun-status').html 'failed'
          $('.jido-data-firstrun-status').removeClass 'badge-danger'
          $('.jido-data-firstrun-status').removeClass 'badge-success'
          $('.jido-data-firstrun-status').removeClass 'badge-light'
          $('.jido-data-firstrun-status').addClass 'badge-danger'

          failedUpload 'firstrun'
        else
          $('.jido-data-firstrun-status').html 'changed'
          $('.jido-data-firstrun-status').removeClass 'badge-danger'
          $('.jido-data-firstrun-status').removeClass 'badge-success'
          $('.jido-data-firstrun-status').removeClass 'badge-light'
          $('.jido-data-firstrun-status').addClass 'badge-success'
          $(".token-alert").hide()

          putToken sha256
          successUpload 'firstrun'
          $('#setuptoken-input').val ''
          $('#setuptoken1-input').val ''
          $('#setuptoken2-input').val ''
          $('.jido-page-content-firstrun .jido-panel-network').hide()
          loadHome()

### generic start here ###

logoutButtonListener()
loginButtonListener()
newTokenButtonListener()
tokenButtonListener()
setuptokenButtonListener()

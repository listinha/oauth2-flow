require 'pry-byebug'
require 'spyder'
require 'cgi'
require 'json'
require 'excon'
require 'securerandom'

$secrets = JSON.load(File.read 'secrets.json')
$redirect_uri = 'http://localhost:9695/oauth2_redirect_url'

def dropbox_auth_headers
  credentials = JSON.load(File.read 'dropbox_credentials.json')

  expiry_time = Time.parse(credentials['current_time']) + credentials['expires_in']
  if Time.now.utc > (expiry_time - 5 * 60)
    post_params = {
      refresh_token: credentials['refresh_token'],
      grant_type: 'refresh_token',
      client_id: $secrets['dropbox_app_key'],
      client_secret: $secrets['dropbox_app_secret']
    }
    post_params_str = post_params.map do |key, value|
      "#{key}=#{CGI.escape(value)}"
    end.join('&')

    result = Excon.post('https://api.dropboxapi.com/oauth2/token',
      body: post_params_str,
      headers: {
        'Content-Type' => 'application/x-www-form-urlencoded'
      })

    credentials.merge!(JSON.parse(result.body).merge('current_time' => Time.now.utc.to_s))
    File.write('dropbox_credentials.json', JSON.dump(credentials))
  end

  {
    'Authorization' => "Bearer #{credentials['access_token']}",
  }
end

server = Spyder::Server.new('0.0.0.0', 9695)

server.router.add_route 'GET', '/thumb/:file_path' do |request, route_params|
  resp = Spyder::Response.new
  resp.add_standard_headers
  path = CGI.unescape( route_params[:file_path] )

  resp.set_header 'content-type', 'image/jpeg'

  r = Excon.post("https://content.dropboxapi.com/2/files/get_thumbnail_v2",
    headers: dropbox_auth_headers.merge({
      'Dropbox-API-Arg' => JSON.dump({ resource: { '.tag' => 'path', path: }, size: 'w256h256' })
    }))

  resp.body = r.body

  resp
end

server.router.add_route 'GET', '/dropbox_files' do |request, _|
  reqresp = Spyder::Response.new
  reqresp.add_standard_headers
  reqresp.set_header 'content-type', 'text/html'

  resp = Excon.post("https://api.dropboxapi.com/2/files/list_folder",
    headers: dropbox_auth_headers.merge({     'Content-Type' => 'application/json' }),
    body: JSON.dump({
      include_media_info: true,
      path: '/just-some-pictures',
      recursive: false,
    }))

  resp_body = JSON.load(resp.body)
  html = resp_body['entries'].map do |file|
    file_name = file['name']
    path = file['path_display']

    "<li>#{file_name} <img width=256 height=256 src=\"/thumb/#{CGI.escape(path)}\"></li>"
  end

  reqresp.body = <<~HTML
    <h1>You're connected!</h1>

    <ol>
      #{html.join("\n")}
    <ol>
  HTML

  reqresp
end

server.router.add_route 'GET', '/' do |request, _|
  app_key = $secrets['dropbox_app_key']
  state = SecureRandom.uuid

  resp = Spyder::Response.new
  resp.add_standard_headers
  resp.set_header 'content-type', 'text/html'
  resp.set_header 'set-cookie', "user_state=#{state}"
  resp.body = <<~HTML
    <h1>Let's connect to dropbox!</h1>

    <p>
      <a target="_blank" href="https://www.dropbox.com/oauth2/authorize?token_access_type=offline&client_id=#{app_key}&response_type=code&redirect_uri=#{CGI.escape($redirect_uri)}&state=#{state}">Connect to Dropbox</a>
    </p>
  HTML

  resp
end

server.router.add_route 'GET', '/oauth2_redirect_url' do |request, other|
  code = request.query_params['code']
  given_state = request.query_params['state']
  expected_state = request.headers.dict['cookie'].split('=')[1]

  if given_state != expected_state
    resp = Spyder::Response.new
    resp.add_standard_headers
    resp.code = 400
    resp.set_header 'Content-Type', 'text/plain'
    resp.body = 'The provided state does not match the user! You are a hacker!'

    next resp
  end

  post_params = {
    code:,
    grant_type: 'authorization_code',
    redirect_uri: $redirect_uri,
    client_id: $secrets['dropbox_app_key'],
    client_secret: $secrets['dropbox_app_secret']
  }
  post_params_str = post_params.map do |key, value|
    "#{key}=#{CGI.escape(value)}"
  end.join('&')

  result = Excon.post('https://api.dropboxapi.com/oauth2/token',
    body: post_params_str,
    headers: {
      'Content-Type' => 'application/x-www-form-urlencoded'
    })

  json = JSON.dump(JSON.parse(result.body).merge('current_time' => Time.now.utc.to_s))
  File.write('dropbox_credentials.json', json)

  resp = Spyder::Response.new
  resp.add_standard_headers
  resp.code = 307
  resp.set_header 'Location', '/dropbox_files'

  resp
end

server.start

require "rubygems"
require "bundler/setup"

require "eventmachine"
require "evma_httpserver"

class AssetServer < EventMachine::Connection
  include EventMachine::HttpServer

  def process_http_request
    p [:incoming_path, @http_path_info]
    _, app, timestamp, path = @http_path_info.split("/", 4)

    resp = EventMachine::DelegatedHttpResponse.new(self)

    unless app && timestamp && path
      resp.status = 404
      resp.content = "Not Found"
      resp.send_reponse
      return
    end

    p [:app, app]
    p [:timestamp, timestamp]
    p [:path, path]

    # query our threaded server (max concurrency: 20)
    http = EM::Protocols::HttpClient.request(
      :host => "#{app}.heroku.com",
      :port => 80,
      :request => path
    )

    http.errback do |r|
      p [:errback, r.inspect]
    end

    # once download is complete, send it to client
    http.callback do |r|
      #p [:callback, r.inspect]
      resp.status  = r[:status]
      resp.content = r[:content]
      resp.send_response
    end
  end
end

EventMachine::run do
  EventMachine.epoll
  EventMachine.start_server("0.0.0.0", ENV["PORT"], AssetServer)
end


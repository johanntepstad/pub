# -- CONFIGURE FALCON AS THE PRIMARY WEB SERVER --

bundle add falcon
bundle add async
bundle add async-redis
bundle add async-websocket

bundle install

# Generate Falcon configuration for each app
typeset -A apps_domains
apps_domains = {
  "brgen" => ENV["BRGEN_PORT"],
  "bsdports" => ENV["BSDPORTS_PORT"],
  "neuroticerotic" => ENV["NEUROTICEROOT_PORT"]
}

apps_domains.each do |app, port|
  config_content = <<~EOF
    #!/usr/bin/env falcon-host
    # Falcon for Rails with ActionCable support

    ENV["RAILS_ENV"] ||= "production"

    require_relative "./config/environment"
    require "async/websocket/adapters/rack"

    load :rack, :supervisor

    Async do
      hostname = "localhost"

      rails = Rack::Builder.new do
        map "/cable" do
          run ActionCable.server
        end

        run Rails.application
      end

      rack hostname do
        endpoint Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
        app rails
      end

      supervisor
    end
  EOF

  File.write("/home/#{app}/#{app}/config/falcon.rb", config_content)
end

commit_to_git "Set up Falcon as the new web server with Async support"

# frozen_string_literal: true

require "http"
require "benchmark"

RSpec.describe "End-to-end" do
  before :all do
    skip("skipping end-to-end tests") unless ENV["ENABLE_EXTERNAL_TESTS"] == "true"
  end

  before :all do
    Bundler.with_unbundled_env do
      system("gem build -o rage-local.gem && gem install rage-local.gem --no-document && bundle install")
      @pid = spawn("bundle exec rage s", chdir: "spec/integration/test_app")
      sleep(1)
    end
  end

  after :all do
    if @pid
      Process.kill(:SIGTERM, @pid)
      Process.wait
      system("rm spec/integration/test_app/Gemfile.lock")
    end
  end

  it "correctly processes lambda requests" do
    response = HTTP.get("http://localhost:3000")
    expect(response.code).to eq(200)
    expect(response.to_s).to eq("It works!")
  end

  it "correctly processes get requests" do
    response = HTTP.get("http://localhost:3000/get")
    expect(response.code).to eq(200)
    expect(response.to_s).to eq("i am a get response")
  end

  it "correctly processes post requests" do
    response = HTTP.post("http://localhost:3000/post")
    expect(response.code).to eq(200)
    expect(response.to_s).to eq("i am a post response")
  end

  it "correctly processes put requests" do
    response = HTTP.put("http://localhost:3000/put")
    expect(response.code).to eq(200)
    expect(response.to_s).to eq("i am a put response")
  end

  it "correctly processes patch requests" do
    response = HTTP.patch("http://localhost:3000/patch")
    expect(response.code).to eq(200)
    expect(response.to_s).to eq("i am a patch response")
  end

  it "correctly processes delete requests" do
    response = HTTP.delete("http://localhost:3000/delete")
    expect(response.code).to eq(200)
    expect(response.to_s).to eq("i am a delete response")
  end

  it "correctly processes empty requests" do
    response = HTTP.get("http://localhost:3000/empty")
    expect(response.code).to eq(204)
    expect(response.to_s).to eq("")
  end

  it "correctly responds with 404" do
    response = HTTP.get("http://localhost:3000/unknown")
    expect(response.code).to eq(404)
  end

  it "correctly responds with 500" do
    response = HTTP.get("http://localhost:3000/raise_error")
    expect(response.code).to eq(500)
    expect(response.to_s).to start_with("RuntimeError:1155 test error")
  end

  it "sets correct headers" do
    response = HTTP.get("http://localhost:3000/get")
    expect(response.headers["content-type"]).to eq("text/plain; charset=utf-8")
  end

  context "with params" do
    it "correctly parses query params" do
      response = HTTP.get("http://localhost:3000/params/digest?test=true&message=hello+world")
      expect(response.code).to eq(200)
      expect(response.to_s).to eq("e51b2c9c5399485acbc88f60f4f782c5")
    end

    it "correctly parses url params" do
      response = HTTP.get("http://localhost:3000/params/1144/defaults")
      expect(response.code).to eq(200)
      expect(response.to_s).to eq("49d0c01df27b9b15b558554439bdfd00")
    end

    it "correctly parses json body" do
      response = HTTP.post("http://localhost:3000/params/digest?hello=w+o+r+l+d", json: { id: 10, test: true })
      expect(response.code).to eq(200)
      expect(response.to_s).to eq("beda497e73ccdbe91c140377b9dc5e48")
    end

    it "correctly parses multipart body" do
      response = HTTP.post("http://localhost:3000/params/multipart", form: {
        id: 12345,
        text: HTTP::FormData::File.new("spec/fixtures/2kb.txt")
      })

      expect(response.code).to eq(200)
      expect(response.to_s).to eq("662b82a8999aa1ce53d67dcc6d3e3605")
    end

    it "correctly parses urlencoded body" do
      response = HTTP.post("http://localhost:3000/params/digest", form: {
        "users[][id]" => 11,
        "users[][name]" => 22
      })

      expect(response.code).to eq(200)
      expect(response.to_s).to eq("0f825fc37d17c300570e3252ea648563")
    end
  end

  context "with async" do
    it "correctly pauses and resumes requests" do
      response = HTTP.get("http://localhost:3000/async/sum")
      expect(response.code).to eq(200)
      expect(response.to_s).to eq("192")
    end

    it "doesn't block" do
      threads = nil

      time_spent = Benchmark.realtime do
        threads = 3.times.map do |i|
          Thread.new { HTTP.get("http://localhost:3000/async/long?i=#{10 + i}") }
        end
        threads.each(&:join)
      end

      responses = threads.map(&:value)
      expect(responses.map(&:code).uniq).to eq([200])
      expect(responses.map(&:to_s)).to match_array(%w(100 110 120))

      expect(time_spent).to be < 1.5
    end

    it "correctly sends default response" do
      response = HTTP.timeout(2).get("http://localhost:3000/async/empty")
      expect(response.code).to eq(204)
      expect(response.to_s).to eq("")
    end
  end

  context "with before actions" do
    it "correctly processes the request" do
      response = HTTP.get("http://localhost:3000/before_actions/get")
      expect(response.parse).to eq({ "message" => "hello world" })
    end

    it "correctly processes the request" do
      response = HTTP.get("http://localhost:3000/before_actions/get?with_timestamp=true")
      expect(response.parse).to eq({ "message" => "hello world", "timestamp" => 1636466868 })
    end
  end
end

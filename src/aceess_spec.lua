local spec_helper = require "spec.spec_helpers"
local http_client = require "kong.tools.http_client"

local STUB_GET_URL = spec_helper.STUB_GET_URL
local STUB_POST_URL = spec_helper.STUB_POST_URL

describe("Middleman Plugin", function()

  setup(function()
    spec_helper.prepare_db()
    
    --

    spec_helper.start_kong()
  end)

  teardown(function()
    spec_helper.stop_kong()
  end)

  describe("Middleman", function()
     it("should return an Hello-World header with Hello World!!! value when say_hello is true", function()
      local _, status, headers = http_client.get(STUB_GET_URL, {}, {host = "helloworld1.com"})
      assert.are.equal(200, status)
      assert.are.same("Hello World!!!", headers["hello-world"])
    end)
  end)
end)
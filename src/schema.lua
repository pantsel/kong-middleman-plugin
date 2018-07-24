return {
  no_consumer = true,
  fields = {
    url = {required = true, type = "string"},
    timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" }
  }
}
structures = "test/yggdrasil/test/"
Code.require_file(structures <> "test_broker.exs")
Code.require_file(structures <> "test_subscriber.exs")
Code.require_file(structures <> "test_generic_broker.exs")
ExUnit.start()

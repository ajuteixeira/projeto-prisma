defmodule ProjetoPrisma.Sync.AdaptersTest do
  use ExUnit.Case, async: true

  alias ProjetoPrisma.Sync.Adapters

  describe "get_adapter/1" do
    test "returns the implemented PSN adapter for playstation" do
      assert ProjetoPrisma.Sync.Psn.Adapter == Adapters.get_adapter(:playstation)
    end

    test "returns the implemented Xbox adapter for xbox" do
      assert ProjetoPrisma.Sync.Xbox.Adapter == Adapters.get_adapter(:xbox)
    end
  end
end

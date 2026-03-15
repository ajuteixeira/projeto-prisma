defmodule ProjetoPrisma.Sync.Adapters do
  @moduledoc """
  Factory que retorna o adapter correto baseado na plataforma.

  Usa a factory pattern para centralizar a seleção de adapters,
  facilitando adicionar novas plataformas no futuro.
  """

  @doc """
  Retorna o módulo do adapter para a plataforma especificada.

  ## Exemplos

      iex> ProjetoPrisma.Sync.Adapters.get_adapter(:steam)
      ProjetoPrisma.Sync.Steam.Adapter

      iex> ProjetoPrisma.Sync.Adapters.get_adapter(:playstation)
      ProjetoPrisma.Sync.PlayStation.Adapter

      iex> ProjetoPrisma.Sync.Adapters.get_adapter(:invalid)
      {:error, "Plataforma invalid não suportada"}
  """
  def get_adapter(:steam), do: ProjetoPrisma.Sync.Steam.Adapter
  def get_adapter(:playstation), do: ProjetoPrisma.Sync.PlayStation.Adapter
  def get_adapter(:xbox), do: ProjetoPrisma.Sync.Xbox.Adapter
  def get_adapter(:retroachievements), do: ProjetoPrisma.Sync.RetroAchievements.Adapter

  def get_adapter(platform) do
    {:error, "Plataforma #{platform} não suportada"}
  end
end

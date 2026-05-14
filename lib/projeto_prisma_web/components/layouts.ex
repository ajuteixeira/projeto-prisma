defmodule ProjetoPrismaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ProjetoPrismaWeb, :html

  # 1. Importa o novo componente modular da Navbar
  import ProjetoPrismaWeb.Layouts.Navbar

  # Embed all files in layouts/* within this module.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string,
    default: "/",
    doc: "path atual da requisição, usado para destacar o item ativo na sidebar"

  attr :variant, :string,
    default: "default",
    values: ["default", "bare"],
    doc: "layout variant — 'bare' omite a sidebar (usado em telas de auth)"

  attr :show_navbar, :boolean,
    default: nil,
    doc: "controla se a navbar deve ser exibida (nil = automático baseado no path)"

  slot :inner_block, required: true

  def app(assigns) do
    show_navbar =
      cond do
        assigns[:show_navbar] != nil -> assigns[:show_navbar]
        assigns[:variant] == "bare" -> false
        true -> show_navbar?(assigns[:current_path] || "/")
      end

    assigns = assign(assigns, :show_navbar, show_navbar)

    ~H"""
    <.render_navbar :if={@show_navbar} current_scope={@current_scope} current_path={@current_path} />

    <%= if @variant == "bare" do %>
      {render_slot(@inner_block)}
    <% else %>
      <main class="min-h-screen">
        <div class="p-6">
          <div class="max-w-7xl mx-auto">
            {render_slot(@inner_block)}
          </div>
        </div>
      </main>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="prisma-alert-stack">
      <.prisma_flash kind={:info} flash={@flash} title={gettext("Sucesso")} />
      <.prisma_flash kind={:error} flash={@flash} title={gettext("Erro")} />

      <.prisma_flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-4 motion-safe:animate-spin" />
      </.prisma_flash>

      <.prisma_flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-4 motion-safe:animate-spin" />
      </.prisma_flash>
    </div>
    """
  end

  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  defp prisma_flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      role="alert"
      class={[
        "prisma-alert",
        @kind == :info && "prisma-alert-info",
        @kind == :error && "prisma-alert-error"
      ]}
      {@rest}
    >
      <div class="prisma-alert-icon">
        <.icon :if={@kind == :info} name="hero-check-circle" class="size-5" />
        <.icon :if={@kind == :error} name="hero-exclamation-triangle" class="size-5" />
      </div>

      <div class="prisma-alert-copy">
        <p :if={@title} class="prisma-alert-title">{@title}</p>
        <p class="prisma-alert-message">{msg}</p>
      </div>

      <button
        type="button"
        class="prisma-alert-close"
        aria-label={gettext("close")}
        phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      >
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
    """
  end

  @doc """
  Determina se a navbar deve ser exibida com base no path atual.

  A navbar é exibida por padrão em todas as telas, exceto nas listadas
  na lista de exceções `@navbar_hidden_paths`.

  """
  @navbar_hidden_paths [
    "/log-in",
    "/users/log-in",
    "/users/register",
    "/register",
    "/reset-password",
    "/connect-platforms"
  ]

  def show_navbar?(path) do
    not Enum.any?(@navbar_hidden_paths, fn hidden_path ->
      path == hidden_path or String.starts_with?(path, hidden_path <> "/") or
        String.starts_with?(path, hidden_path <> "?")
    end)
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end

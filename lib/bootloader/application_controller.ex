defmodule Bootloader.ApplicationController do
  use GenServer

  alias Bootloader.Utils

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def hash() do
    GenServer.call(__MODULE__, :hash)
  end

  def applications() do
    GenServer.call(__MODULE__, :applications)
  end

  def apply_overlay(overlay) do
    GenServer.call(__MODULE__, {:overlay, :apply, overlay})
  end

  def init(opts) do
    app = opts[:app]
    init =  opts[:init] || []
    overlay_path = opts[:overlay_path]
    handler = opts[:handler] || Bootloader.Handler

    s = %{
      init: init,
      app: app,
      overlay_path: overlay_path,
      handler: handler,
      handler_state: handler.init()
    }

    send(self(), :init)

    {:ok, s}
  end

  def handle_call(:hash, _from, s) do
    hash =
      ([s.app] ++ s.init)
      |> Enum.map(&Bootloader.Application.load/1)
      |> Enum.uniq
      |> Enum.map(& &1.hash)
      |> Enum.join
      |> Utils.hash
    {:reply, hash, s}
  end

  def handle_call(:applications, _from, s) do
    reply =
      Enum.map([s.app | s.init], &Bootloader.Application.load/1)
    {:reply, reply, s}
  end

  def handle_call({:overlay, :apply, overlay}, _from, s) do
    reply = Bootloader.Overlay.apply(overlay, s.overlay_path)
    {:reply, reply, s}
  end

  # Bootloader Application Init Phase
  def handle_info(:init, s) do
    for app <- s.init do
      Application.ensure_all_started(app)
    end
    send(self(), :app)
    {:noreply, s}
  end

  # Bootloader Application Start Phase
  def handle_info(:app, s) do
    Application.ensure_all_started(s.app)
    {:noreply, s}
  end

end

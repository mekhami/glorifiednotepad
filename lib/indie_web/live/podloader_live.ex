defmodule IndieWeb.PodloaderLive do
  use IndieWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="podloader-page" class="min-h-screen bg-zinc-950 text-green-400 font-mono px-4 py-16">
        <%!-- Terminal-style header --%>
        <div class="max-w-2xl mx-auto">
          <div class="border border-green-700 rounded-sm p-6 mb-8 bg-zinc-900">
            <p class="text-green-600 text-sm mb-1">$ ./podloader --info</p>
            <h1 class="text-4xl font-bold tracking-tight text-green-300 mb-2">
              PODLOADER
            </h1>
            <p class="text-green-500 text-sm">
              v1.0.0 &nbsp;·&nbsp; macOS &nbsp;·&nbsp; made by a human
            </p>
          </div>

          <%!-- Description block --%>
          <div class="mb-10 space-y-3 text-green-400 leading-relaxed">
            <p class="text-green-300">
              a little app i made. it loads pods.
            </p>
            <p>
              drag it in, press play, done. no accounts. no cloud. no nonsense.
            </p>
            <p class="text-green-600 text-sm">
              requires macOS 13+
            </p>
          </div>

          <%!-- Download button --%>
          <div class="mb-12">
            <a
              id="download-btn"
              href="/downloads/podloader.dmg"
              download
              class={[
                "inline-block border-2 border-green-500 text-green-300 px-8 py-4",
                "text-lg font-bold tracking-widest uppercase",
                "hover:bg-green-500 hover:text-zinc-950",
                "transition-colors duration-150",
                "focus:outline-none focus:ring-2 focus:ring-green-400"
              ]}
            >
              [ download .dmg ]
            </a>
            <p class="mt-3 text-green-700 text-xs">
              free. always will be.
            </p>
          </div>

          <%!-- Footer breadcrumb --%>
          <div class="border-t border-zinc-800 pt-6 text-xs text-zinc-600">
            <.link navigate={~p"/"} class="hover:text-green-600 transition-colors">
              ← back to the notepad
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

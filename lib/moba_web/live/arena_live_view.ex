defmodule MobaWeb.ArenaLiveView do
  use MobaWeb, :live_view

  alias MobaWeb.Tutorial

  def mount(_, %{"user_id" => user_id}, socket) do
    socket = assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)
    hero = Game.current_pvp_hero(socket.assigns.current_user)

    if hero do
      {filter, results} = Game.pvp_search(hero)

      if connected?(socket) do
        hero.id
        |> Game.subscribe_to_hero()
        |> Tutorial.subscribe()
      end

      {:ok,
       assign(socket,
         search_results: results,
         current_hero: hero,
         filter: filter,
         sort: "hp",
         page: 1,
         tutorial_step: hero.user.tutorial_step,
         pending_battle: Engine.pending_battle(hero.id)
       )}
    else
      {:ok, socket |> push_redirect(to: "/arena/select")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, Tutorial.next_step(socket, 13)}
  end

  def handle_event("search", params, socket) do
    filter = params["filter"] || socket.assigns.filter
    sort = params["sort"] || socket.assigns.sort
    results = Game.pvp_search(socket.assigns.current_hero, filter, sort, 1)
    {:noreply, assign(socket, filter: filter, sort: sort, search_results: results, page: 1)}
  end

  def handle_event("page", %{"number" => number}, socket) do
    page = process_page(number)
    results = Game.pvp_search(socket.assigns.current_hero, socket.assigns.filter, socket.assigns.sort, page)
    {:noreply, assign(socket, page: page, search_results: results)}
  end

  def handle_event("battle", %{"id" => id, "number" => build_id}, socket) do
    redirect_to_battle(id, build_id, socket)
  end

  def handle_event("finish-tutorial", _, socket) do
    {:noreply, Tutorial.finish(socket)}
  end

  def handle_info({"battle", %{id: id, build_id: build_id}}, socket) do
    redirect_to_battle(id, build_id, socket)
  end

  def handle_info({"tutorial-step", %{step: step}}, socket) do
    {:noreply, assign(socket, tutorial_step: step)}
  end

  def handle_info({"hero", %{id: id}}, socket) do
    {:noreply, assign(socket, current_hero: Game.get_hero!(id))}
  end

  def handle_info({"unread", _}, socket), do: {:noreply, socket}

  def render(assigns) do
    MobaWeb.ArenaView.render("index.html", assigns)
  end

  defp redirect_to_battle(id, build_id, socket) do
    build = Game.get_build!(build_id)
    defender = Game.get_hero!(id) |> Map.put(:active_build, build)
    attacker = Game.get_hero!(socket.assigns.current_hero.id)

    battle =
      %{attacker: attacker, defender: defender}
      |> Engine.create_pvp_battle!()

    {:noreply, socket |> push_redirect(to: Routes.live_path(socket, MobaWeb.BattleLiveView, battle.id))}
  end

  defp process_page(page) do
    result = String.to_integer(page)

    if result <= 0 do
      1
    else
      result
    end
  end
end

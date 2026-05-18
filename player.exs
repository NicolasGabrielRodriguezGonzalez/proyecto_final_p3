# =============================================================
#  AZAR S.A. - Cliente Jugador
#  Ejecutar: elixir --sname player --cookie azar player.exs
# =============================================================

Mix.install([{:jason, "~> 1.4"}])

Code.require_file("shared/json_store.exs",      __DIR__)
Code.require_file("shared/cliente_router.exs",  __DIR__)
Code.require_file("player/auth.exs",            __DIR__)
Code.require_file("player/notificaciones.exs",  __DIR__)
Code.require_file("player/compras_menu.exs",    __DIR__)
Code.require_file("player/cli.exs",             __DIR__)

# Detectar hostname automaticamente
hostname = Node.self() |> to_string() |> String.split("@") |> Enum.at(1)
server_node = String.to_atom("server@" <> hostname)

IO.puts("Conectando a: " <> to_string(server_node))

case Node.connect(server_node) do
  true ->
    IO.puts(" [OK] Conectado al servidor")
  false ->
    IO.puts(" [ERROR] No se pudo conectar a " <> to_string(server_node))
    IO.puts("         Ejecute primero: elixir --sname server --cookie azar server.exs")
    System.halt(1)
end

# Dar un momento para que :global sincronice el Router
:timer.sleep(500)

IO.puts("")
IO.puts("╔══════════════════════════════════════════════╗")
IO.puts("║          AZAR S.A. - Sistema de Sorteos      ║")
IO.puts("║               PORTAL JUGADOR                 ║")
IO.puts("╚══════════════════════════════════════════════╝")
IO.puts("")

Azar.Player.CLI.start()

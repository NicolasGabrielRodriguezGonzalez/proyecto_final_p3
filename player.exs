# =============================================================
#  AZAR S.A. - Cliente Jugador
#  Ejecutar: elixir --name player@TU_IP --cookie azar player.exs
# =============================================================

Mix.install([{:jason, "~> 1.4"}])

Code.require_file("shared/json_store.exs",     __DIR__)
Code.require_file("shared/cliente_router.exs", __DIR__)
Code.require_file("player/auth.exs",           __DIR__)
Code.require_file("player/notificaciones.exs", __DIR__)
Code.require_file("player/compras_menu.exs",   __DIR__)
Code.require_file("player/cli.exs",            __DIR__)

# IP fija del servidor
server_node = :"server@192.168.1.59"

IO.puts("Conectando a: " <> to_string(server_node))

case Node.connect(server_node) do
  true ->
    IO.puts(" [OK] Conectado al servidor")
  false ->
    IO.puts(" [ERROR] No se pudo conectar a " <> to_string(server_node))
    IO.puts("         Verifique que server.exs corre en 192.168.1.59")
    System.halt(1)
end

:timer.sleep(500)

IO.puts("")
IO.puts("╔══════════════════════════════════════════════╗")
IO.puts("║          AZAR S.A. - Sistema de Sorteos      ║")
IO.puts("║               PORTAL JUGADOR                 ║")
IO.puts("╚══════════════════════════════════════════════╝")
IO.puts("")

Azar.Player.CLI.start()

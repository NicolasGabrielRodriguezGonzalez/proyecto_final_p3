# =============================================================
#  AZAR S.A. - Cliente Administrador
#  Ejecutar: elixir --name admin@TU_IP --cookie azar admin.exs
# =============================================================

Mix.install([{:jason, "~> 1.4"}])

Code.require_file("shared/json_store.exs",     __DIR__)
Code.require_file("shared/cliente_router.exs", __DIR__)
Code.require_file("admin/sorteos_menu.exs",    __DIR__)
Code.require_file("admin/premios_menu.exs",    __DIR__)
Code.require_file("admin/cli.exs",             __DIR__)

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
IO.puts("║             PANEL ADMINISTRADOR              ║")
IO.puts("╚══════════════════════════════════════════════╝")
IO.puts("")

Azar.Admin.CLI.start()

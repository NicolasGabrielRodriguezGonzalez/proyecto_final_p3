# =============================================================
#  Módulo: Azar.Player.Notificaciones
#  Responsabilidad: Recibir y mostrar notificaciones del servidor
#  - Recibe mensajes push cuando un sorteo se realiza
#  - Permite consultar notificaciones guardadas
# =============================================================

defmodule Azar.Player.Notificaciones do

  # ============================================================
  # RECIBIR NOTIFICACION PUSH (llamado desde el servidor)
  # ============================================================

  @doc """
  Llamado remotamente por el SorteoServer cuando un sorteo se realiza.
  Muestra la notificacion en pantalla inmediatamente.
  """
  def recibir(cliente_doc, mensaje) do
    IO.puts("")
    IO.puts("╔══════════════════════════════════════════╗")
    IO.puts("║           NOTIFICACION NUEVA             ║")
    IO.puts("╠══════════════════════════════════════════╣")
    IO.puts("║ " <> String.pad_trailing(mensaje, 40) <> " ║")
    IO.puts("╚══════════════════════════════════════════╝")
    IO.puts("")
  end

  # ============================================================
  # VER NOTIFICACIONES GUARDADAS
  # ============================================================

  @doc """
  Muestra todas las notificaciones guardadas para el cliente.
  """
  def ver(cliente) do
    IO.puts("")
    IO.puts("=== NOTIFICACIONES ===")

    case Azar.Shared.ClienteRouter.llamar({:get_notificaciones, cliente.documento}) do
      {:ok, []} ->
        IO.puts("No tiene notificaciones.")

      {:ok, notificaciones} ->
        IO.puts("Tiene " <> to_string(length(notificaciones)) <> " notificacion(es):")
        IO.puts("")
        IO.puts(String.duplicate("-", 50))

        Enum.with_index(notificaciones, 1) |> Enum.each(fn {msg, i} ->
          IO.puts(to_string(i) <> ". " <> msg)
          IO.puts("")
        end)

        IO.puts(String.duplicate("-", 50))

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

end

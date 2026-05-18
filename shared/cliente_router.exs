# =============================================================
#  Módulo: Azar.Shared.ClienteRouter
#  Responsabilidad: Llamar al Router del servidor desde nodos remotos
#  Usado por: admin y player
# =============================================================

defmodule Azar.Shared.ClienteRouter do

  @doc """
  Envía una solicitud al Router del servidor.
  Funciona aunque el módulo Router no esté cargado localmente.
  """
  def llamar(solicitud) do
    case :global.whereis_name(:azar_router) do
      :undefined ->
        {:error, "No se encontro el servidor. Verifique la conexion."}
      pid ->
        GenServer.call(pid, solicitud, 10_000)
    end
  end

end

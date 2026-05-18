# =============================================================
#  Módulo: Azar.Server.Logger
#  Responsabilidad: Registrar todas las solicitudes del sistema
#  - Muestra en pantalla con colores según resultado
#  - Guarda en log/bitacora.txt
# =============================================================

defmodule Azar.Server.Logger do

  @log_file "log/bitacora.txt"

  # Colores ANSI para la consola
  @color_ok      "\e[32m"   # verde
  @color_error   "\e[31m"   # rojo
  @color_info    "\e[36m"   # cyan
  @color_reset   "\e[0m"

  # ------------------------------------------------------------
  # API PÚBLICA
  # ------------------------------------------------------------

  @doc """
  Registra una solicitud con su resultado.
  Uso: Logger.log("comprar_billete:sorteo_001:cliente_123", :ok)
       Logger.log("login:cliente_123", :error)
  """
  def log(solicitud, resultado) do
    timestamp = timestamp_actual()
    resultado_str = formatear_resultado(resultado)
    linea_archivo = "[#{timestamp}] #{solicitud} => #{resultado_str}"
    linea_pantalla = colorear(resultado, "[#{timestamp}] #{solicitud} => #{resultado_str}")

    # Mostrar en pantalla con color
    IO.puts(linea_pantalla)

    # Guardar en archivo sin códigos de color
    guardar_en_archivo(linea_archivo)
  end

  @doc """
  Registra un mensaje informativo general (sin solicitud/resultado).
  Uso: Logger.info("Servidor iniciado correctamente")
  """
  def info(mensaje) do
    timestamp = timestamp_actual()
    linea = "[#{timestamp}] INFO: #{mensaje}"

    IO.puts("#{@color_info}#{linea}#{@color_reset}")
    guardar_en_archivo(linea)
  end

  @doc """
  Registra un error del sistema.
  Uso: Logger.error("No se pudo leer sorteo_001.json")
  """
  def error(mensaje) do
    timestamp = timestamp_actual()
    linea = "[#{timestamp}] ERROR: #{mensaje}"

    IO.puts("#{@color_error}#{linea}#{@color_reset}")
    guardar_en_archivo(linea)
  end

  @doc """
  Escribe una línea separadora en la bitácora.
  Útil para marcar el inicio de una sesión del servidor.
  """
  def separador do
    linea = String.duplicate("=", 60)
    IO.puts(linea)
    guardar_en_archivo(linea)
  end

  # ------------------------------------------------------------
  # FUNCIONES PRIVADAS
  # ------------------------------------------------------------

  defp timestamp_actual do
    {{y, m, d}, {h, min, s}} = :calendar.local_time()
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B", [y, m, d, h, min, s])
    |> to_string()
  end

  defp formatear_resultado(:ok),            do: "OK"
  defp formatear_resultado(:error),         do: "NEGADO"
  defp formatear_resultado({:ok, msg}),     do: "OK - #{msg}"
  defp formatear_resultado({:error, msg}),  do: "NEGADO - #{msg}"
  defp formatear_resultado(otro),           do: inspect(otro)

  defp colorear(:ok, linea),            do: "#{@color_ok}#{linea}#{@color_reset}"
  defp colorear({:ok, _}, linea),       do: "#{@color_ok}#{linea}#{@color_reset}"
  defp colorear(:error, linea),         do: "#{@color_error}#{linea}#{@color_reset}"
  defp colorear({:error, _}, linea),    do: "#{@color_error}#{linea}#{@color_reset}"
  defp colorear(_, linea),              do: "#{@color_info}#{linea}#{@color_reset}"

  defp guardar_en_archivo(linea) do
    # Crear carpeta log/ si no existe
    File.mkdir_p!("log")
    File.write!(@log_file, linea <> "\n", [:append])
  end

end

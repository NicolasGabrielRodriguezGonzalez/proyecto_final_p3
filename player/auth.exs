# =============================================================
#  Módulo: Azar.Player.Auth
#  Responsabilidad: Registro e inicio de sesión de jugadores
# =============================================================

defmodule Azar.Player.Auth do

  # ============================================================
  # REGISTRO DE NUEVO JUGADOR
  # ============================================================

  def registrar do
    IO.puts("")
    IO.puts("=== REGISTRO DE USUARIO ===")

    nombre  = IO.gets("Nombre completo          : ") |> String.trim()
    doc     = IO.gets("Documento de identidad   : ") |> String.trim()
    pass    = IO.gets("Contrasena               : ") |> String.trim()
    pass2   = IO.gets("Confirmar contrasena     : ") |> String.trim()
    tarjeta = IO.gets("Numero de tarjeta (sim.) : ") |> String.trim()

    cond do
      nombre == "" or doc == "" or pass == "" or tarjeta == "" ->
        IO.puts("[ERROR] Todos los campos son obligatorios.")
        {:error, "campos vacios"}

      pass != pass2 ->
        IO.puts("[ERROR] Las contrasenas no coinciden.")
        {:error, "contrasenas no coinciden"}

      String.length(doc) < 6 ->
        IO.puts("[ERROR] El documento debe tener al menos 6 caracteres.")
        {:error, "documento invalido"}

      String.length(pass) < 4 ->
        IO.puts("[ERROR] La contrasena debe tener al menos 4 caracteres.")
        {:error, "contrasena muy corta"}

      true ->
        datos = %{
          nombre:   nombre,
          documento: doc,
          contrasena: pass,
          tarjeta:  tarjeta
        }

        case Azar.Shared.ClienteRouter.llamar({:registrar_cliente, datos}) do
          {:ok, msg} ->
            IO.puts("")
            IO.puts("[OK] " <> msg)
            IO.puts("     Bienvenido, " <> nombre <> "!")
            IO.puts("     Ya puede iniciar sesion con su documento.")
            {:ok, msg}

          {:error, msg} ->
            IO.puts("[ERROR] " <> msg)
            {:error, msg}
        end
    end
  end

  # ============================================================
  # INICIO DE SESION
  # ============================================================

  def login do
    IO.puts("")
    IO.puts("=== INICIAR SESION ===")

    doc  = IO.gets("Documento  : ") |> String.trim()
    pass = IO.gets("Contrasena : ") |> String.trim()

    if doc == "" or pass == "" do
      IO.puts("[ERROR] Documento y contrasena son obligatorios.")
      {:error, "campos vacios"}
    else
      case Azar.Shared.ClienteRouter.llamar({:login, doc, pass}) do
        {:ok, cliente} ->
          IO.puts("")
          IO.puts("[OK] Bienvenido, " <> cliente.nombre <> "!")
          {:ok, cliente}

        {:error, msg} ->
          IO.puts("[ERROR] " <> msg)
          {:error, msg}
      end
    end
  end

end

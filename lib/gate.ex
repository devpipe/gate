
defmodule Gate do
  @moduledoc """
  Gate is a macro-based library that provides pipeline functionality similar to Phoenix's pipelines.
  It allows you to define reusable plug pipelines with conditional execution and use them in your Plug.Router.

  ## Usage

  ```elixir
  defmodule MyApp.Router do
    use Plug.Router
    use Gate

    gate :browser do
      plug :put_resp_content_type, "text/html"
      plug Plug.Logger
      plug :auth_required

      get "/" do
        send_resp(conn, 200, "Welcome to the homepage")
      end
    end

    gate :api do
      plug :put_resp_content_type, "application/json"
      plug Plug.Logger

      get "/api" do
        send_resp(conn, 200, ~s({"message": "Welcome to the API"}))
      end
    end

    match _ do
      send_resp(conn, 404, "Oops!")
    end

    defp put_resp_content_type(conn, type) do
      Plug.Conn.put_resp_content_type(conn, type)
    end

    defp auth_required(conn) do
      if get_req_header(conn, "authorization") == ["Bearer valid_token"] do
        true
      else
        Plug.Conn.send_resp(conn, 401, "Unauthorized")
        false
      end
    end
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      import Gate
      @before_compile Gate
    end
  end

  @doc """
  Defines a pipeline of plugs with an optional name.

  ## Example

      gate :browser do
        plug :put_resp_content_type, "text/html"
        plug Plug.Logger
      end
  """
  defmacro gate(name, do: block) do
    quote do
      @current_gate unquote(name)
      Module.register_attribute(__MODULE__, unquote(name), accumulate: true)
      unquote(block)
    end
  end

  @doc """
  Adds a plug to the current pipeline. Optionally accepts a list of conditions that
  must be met for the plug to be applied.

  ## Example

      plug :put_resp_content_type, "text/html"
      plug Plug.Logger, []
      plug MyAuthPlug, [], [auth_required: true]
  """
  defmacro plug(module, opts \\ [], conditions \\ []) do
    quote do
      Module.put_attribute(__MODULE__, @current_gate, {unquote(module), unquote(opts), unquote(conditions)})
    end
  end

  @doc """
  Defines a GET route within the current pipeline.

  ## Example

      get "/" do
        send_resp(conn, 200, "Welcome to the homepage")
      end
  """
  defmacro get(path, do: block) do
    quote do
      @routes {:get, unquote(path), @current_gate, fn conn -> unquote(block) end}
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def init(options), do: options

      @doc false
      def call(conn, _opts) do
        case {conn.method, conn.request_path} do
          {method, path} when is_binary(path) ->
            Enum.find(@routes, fn {r_method, r_path, _pipeline, _fun} ->
              r_method == method and r_path == path
            end)
            |> case do
              nil -> Plug.Conn.send_resp(conn, 404, "Oops!")
              {_, _, pipeline, fun} ->
                conn
                |> apply_pipeline(pipeline)
                |> fun.()
            end
        end
      end

      defp apply_pipeline(conn, pipeline) do
        Enum.reduce_while(pipeline, conn, fn {plug, opts, conditions}, conn ->
          if Enum.all?(conditions, fn cond -> apply(__MODULE__, cond, [conn]) end) do
            case apply(plug, :call, [conn, opts]) do
              %Plug.Conn{halted: true} = halted_conn ->
                {:halt, halted_conn}
              conn ->
                {:cont, conn}
            end
          else
            {:cont, conn}
          end
        end)
      end

      @routes Module.get_attribute(__MODULE__, :routes) || []
    end
  end
end

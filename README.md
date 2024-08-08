
# Gate Library

Gate is a macro-based library that provides pipeline functionality similar to Phoenix's pipelines. It allows you to define reusable plug pipelines with conditional execution and use them in your Plug.Router.

## Installation

Add `Gate` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:plug, "~> 1.11"},
    {:cowboy, "~> 2.9"},
    {:gate, "~> 0.0.1"}.
  ]
end
```

Then, run `mix deps.get` to fetch the dependencies.

## Usage

Define your router using the `Gate` library:

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

## License

This project is licensed under the MIT License.

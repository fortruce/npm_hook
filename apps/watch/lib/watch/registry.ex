defmodule Watch.Registry do
  use GenServer
  require Logger

  alias Timex.{Date,DateFormat}

  @npm_url "https://skimdb.npmjs.com/registry/_design/app/_view/updated"
  @amqp_queue "npm"

  defp update_url(key) do
    @npm_url <> "?" <> URI.encode_query(%{start_key: "\"#{key}\"", limit: 5})
  end

  defp publish_package(%{"id" => name, "key" => key}, chan) do
    Logger.info "Package: #{name}"
  end

  defp poll(key) do
    %HTTPoison.Response{body: body} = HTTPoison.get! update_url(key)
    body
    |> Poison.decode!
    |> Map.get("rows")
    |> Enum.drop_while(&(Map.get(&1, "key") == key))
  end

  defp send_after(msg) do
    Process.send_after(self(), msg, 2 * 1000)
  end

  # Client

  def start_link() do
    Logger.info "Watching NPM Registry"
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_args) do
    send_after(:poll)
    send_after(:test)

    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, @amqp_queue)

    {:ok, key} = Date.now |> DateFormat.format("{ISOz}")
    {:ok, {key, channel}}
  end

  # Callbacks

  def handle_info(:test, {key, chan}) do
    publish_package(%{
      "id" => "test_please_ignore",
      "key" => DateFormat.format(Date.now, "{ISOz}")
    }, chan)
    send_after(:test)
    {:noreply, {key, chan}}
  end

  def handle_info(:poll, {key, chan}) do
    packages = poll(key)
    Enum.map(packages, &(publish_package(&1, chan)))
    send_after(:poll)
    next_key = case packages do
                 [] -> key
                 [%{"key" => key}|_tail] -> key
    end
    {:noreply, {next_key, chan}}
  end

  def handle_info(msg, state) do
    super(msg, state)
  end
end

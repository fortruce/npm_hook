defmodule Watch.Registry do
  use GenServer
  require Logger

  @npm_url "https://skimdb.npmjs.com/registry/_design/app/_view/updated"

  defp update_url(key) do
    @npm_url <> "?" <> URI.encode_query(%{start_key: "\"#{key}\"", limit: 5})
  end

  defp report_package(%{"id" => name, "key" => key}) do
    Logger.info "Package: #{name}"
    key
  end

  defp query(key) do
    %HTTPoison.Response{body: body} = HTTPoison.get! update_url(key)
    body
    |> Poison.decode!
    |> Map.get("rows")
    |> Enum.drop_while(&(Map.get(&1, "key") == key))
    |> Enum.map(&report_package/1)
  end

  defp send_after do
    Process.send_after(self(), :query, 2 * 1000)
  end

  # Client

  def start_link() do
    Logger.info "Watching NPM Registry"
    GenServer.start_link(__MODULE__, nil)
  end

  def init(args) do
    send_after()
    Timex.Date.now |> Timex.DateFormat.format("{ISOz}")
  end

  # Callbacks

  def handle_info(:query, key) do
    key = case query(key) do
      [] ->
        key
      keys ->
        Enum.at(keys, -1)
    end
    send_after()
    {:noreply, key}
  end

  def handle_info(msg, state) do
    super(msg, state)
  end
end

defmodule Registry.Log do
  use GenServer
  require Logger

  @amqp_queue "npm"

  def start_link() do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_args) do
    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, @amqp_queue)
    AMQP.Basic.consume(channel, @amqp_queue, self(), no_ack: true)
    {:ok, nil}
  end

  def handle_info({:basic_deliver, package, _}, state) do
    Logger.info "Processing update for #{package}"
    {:noreply, state}
  end

  def handle_info(msg, state), do: super(msg, state)
end

defmodule StockExchange.InstrumentProcessor do
  defmodule State, do: defstruct instrument: nil, buys: [], sells: []
  alias StockExchange.Orders.{Buy, Sell}

  use GenServer

  def start_link(instrument) do
    GenServer.start_link(__MODULE__, instrument)
  end
  def books(pid) do
    GenServer.call(pid, :books)
  end

  def buy(pid, price, quantity) do
    GenServer.call(pid, {:buy, price, quantity})
  end

  def sell(pid, price, quantity) do
    GenServer.call(pid, {:sell, price, quantity})
  end

  def price(pid) do
    GenServer.call(pid, :price)
  end

  @spec init(any) :: {:ok, StockExchange.InstrumentProcessor.State.t()}
  def init(init_arg) do
    {:ok, %State{instrument: init_arg}}
  end

  def handle_call(:books, _from, state) do
    %State{buys: buys, sells: sells} = state
    {:reply, {:ok, buys, sells}, state}
  end

  def handle_call({:buy, price, quantity}, _from, state = %State{buys: buys}) do
    new_buys = [%Buy{price: price, quantity: quantity} | buys]
    {:reply, :ok, %State{
      state | buys: Enum.sort_by(new_buys, &(&1.price)) |> Enum.reverse()
    }}
  end

  def handle_call({:sell, price, quantity}, _from, state = %State{sells: sells}) do
    new_sells = [%Sell{price: price, quantity: quantity} | sells]
    {:reply, :ok, %State{state | sells: Enum.sort_by(new_sells, &(&1.price))}}
  end

  def handle_call(:price, _from, state = %State{sells: [lowest | _t]}) do
    {:reply, {:ok, lowest.price}, state}
  end
end

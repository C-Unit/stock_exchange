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

  def handle_call({:buy, price, quantity}, _from, state) do
    %State{buys: buys} = state
    new_buys = [%Buy{price: price, quantity: quantity} | buys]
    {:reply, :ok, %State{state | buys: new_buys}}
  end

  def handle_call({:sell, price, quantity}, _from, state) do
    %State{sells: sells} = state
    new_sells = [%Sell{price: price, quantity: quantity} | sells]
    {:reply, :ok, %State{state | sells: new_sells}}
  end

  def handle_call(:price, _from, state) do
    %State{sells: sells} = state
    [lowest_priced_order | _t] = Enum.sort_by(sells, &(&1.price))
    {:reply, {:ok, lowest_priced_order.price}, state}
  end
end

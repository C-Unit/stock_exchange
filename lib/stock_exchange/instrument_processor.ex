defmodule StockExchange.InstrumentProcessor do
  defmodule State, do: defstruct instrument: nil, buys: [], sells: []
  alias StockExchange.Orders.{Buy, Sell}
  alias StockExchange.{Execution, Transaction}

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

  def cancel(pid, order) do
    GenServer.call(pid, {:cancel, order.id})
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

  def handle_call({:buy, price, quantity}, _from, state = %State{buys: buys, sells: sells}) do
    buy = %Buy{id: make_ref(), price: price, quantity: quantity}
    new_buys = [buy | buys]
      |> Enum.sort_by(&(&1.price))
      |> Enum.reverse()

    case executions(new_buys, sells, %Execution{trigger: buy}) do
      {^new_buys, ^sells, _} ->
        {:reply, {:ok, buy}, %State{state | buys: new_buys}}
      {executed_buys, executed_sells, execution} ->
        {:reply, {:ok, execution}, %State{state | sells: executed_sells, buys: executed_buys}}
    end
  end

  def handle_call({:sell, price, quantity}, _from, state = %State{sells: sells, buys: buys}) do
    sell = %Sell{id: make_ref(), price: price, quantity: quantity}
    new_sells = Enum.sort_by([sell | sells], &(&1.price))

    case executions(buys, new_sells, %Execution{trigger: sell}) do
      {^buys, ^new_sells, _} ->
        {:reply, {:ok, sell}, %State{state | sells: new_sells, buys: buys}}
      {executed_buys, executed_sells, execution} ->
        {:reply, {:ok, execution}, %State{state | sells: executed_sells, buys: executed_buys}}
    end
  end

  def handle_call({:cancel, order_ref}, _from, state = %State{buys: buys}) do
    new_buys = Enum.reject(buys, &(&1.id == order_ref ))
    {:reply, :ok, %State{state | buys: new_buys }}
  end

  def handle_call({:cancel, order = %Sell{}}, _from, state = %State{sells: sells}) do
    new_sells = Enum.reject(sells, &(&1 == order ))
    {:reply, :ok, %State{state | sells: new_sells }}
  end

  def handle_call(:price, _from, state = %State{sells: [lowest | _t]}) do
    {:reply, {:ok, lowest.price}, state}
  end

  defp executions(
    [highest_buy = %Buy{price: bid, quantity: buy_qty} | buys_tail],
    [lowest_sell = %Sell{price: ask, quantity: sell_qty} | sells_tail],
    execution
    ) when bid >= ask and sell_qty == buy_qty do

    executions(buys_tail, sells_tail, %Execution{execution | transactions: [%Transaction{
      buy: %Buy{highest_buy | filled: buy_qty},
      sell: %Sell{lowest_sell | filled: sell_qty}
    } | execution.transactions]})
  end
  defp executions(
    [highest_buy = %Buy{price: bid, quantity: buy_qty} | buys_tail],
    [lowest_sell = %Sell{price: ask, quantity: sell_qty} | sells_tail],
    execution
    ) when bid >= ask and sell_qty < buy_qty do
    partial_buy = %Buy{highest_buy | filled: sell_qty + highest_buy.filled}

    executions([partial_buy | buys_tail], sells_tail, %Execution{execution | transactions: [%Transaction{
      buy: partial_buy,
      sell: %Sell{lowest_sell | filled: sell_qty}
    } | execution.transactions]})
  end
  defp executions(
    [highest_buy = %Buy{price: bid, quantity: buy_qty} | buys_tail],
    [lowest_sell = %Sell{price: ask, quantity: sell_qty} | sells_tail],
    execution
    ) when bid >= ask and sell_qty > buy_qty do
    partial_sell = %Sell{lowest_sell | filled: buy_qty + lowest_sell.filled}

    executions(buys_tail, [partial_sell | sells_tail], %Execution{execution | transactions: [%Transaction{
      buy: %Buy{highest_buy | filled: buy_qty},
      sell: partial_sell
    } | execution.transactions]})
  end
  # base case
  defp executions(buys, sells, execution), do: {buys, sells, execution}
end

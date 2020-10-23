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
    buy = %Buy{price: price, quantity: quantity}
    new_buys = [buy | buys]
      |> Enum.sort_by(&(&1.price))
      |> Enum.reverse()

    case executions(new_buys, sells, %Execution{trigger: buy}) do
      {^new_buys, ^sells, _} ->
        {:reply, :ok, %State{state | buys: new_buys}}
      {executed_buys, executed_sells, execution} ->
        {:reply, {:ok, execution}, %State{state | sells: executed_sells, buys: executed_buys}}
    end
  end

  def handle_call({:sell, price, quantity}, _from, state = %State{sells: sells, buys: buys}) do
    sell = %Sell{price: price, quantity: quantity}
    new_sells = Enum.sort_by([sell | sells], &(&1.price))

    case executions(buys, new_sells, %Execution{trigger: sell}) do
      {^buys, ^new_sells, _} ->
        {:reply, :ok, %State{state | sells: new_sells, buys: buys}}
      {executed_buys, executed_sells, execution} ->
        {:reply, {:ok, execution}, %State{state | sells: executed_sells, buys: executed_buys}}
    end
  end

  def handle_call(:price, _from, state = %State{sells: [lowest | _t]}) do
    {:reply, {:ok, lowest.price}, state}
  end

  defp executions(
    [highest_buy = %Buy{price: bid, quantity: buy_qty} | buys_tail],
    [lowest_sell = %Sell{price: ask, quantity: sell_qty} | sells_tail],
    execution
    ) when bid >= ask and sell_qty == buy_qty do
    # crossed the spread, equal quantity order available

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
    # crossed the spread
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
    # crossed the spread
    partial_sell = %Sell{lowest_sell | filled: buy_qty + lowest_sell.filled}

    executions(buys_tail, [partial_sell | sells_tail], %Execution{execution | transactions: [%Transaction{
      buy: %Buy{highest_buy | filled: buy_qty},
      sell: partial_sell
    } | execution.transactions]})
  end
  # TODO: crossed the spread, multiple sells needed to fill buy
  # TODO: crossed the spread, multiple buys fullfilled by sell
  # TODO: crossed the spread, partial sell needed to fill buy
  # TODO: crossed the spread, partial buy needed to fill sell
  # base case
  defp executions(buys, sells, execution), do: {buys, sells, execution}
end

defmodule StockExchange.InstrumentProcessorTest do
  use ExUnit.Case
  alias StockExchange.InstrumentProcessor
  alias StockExchange.Orders.{Buy, Sell}
  alias StockExchange.{Execution, Transaction}

  setup do
    {:ok, pid} = InstrumentProcessor.start_link("AAPL")
    {:ok, pid: pid}
  end

  test "shows the order books", %{pid: pid} = _context do
    {:ok, buys, sells} = InstrumentProcessor.books(pid)
    assert [] = buys
    assert [] = sells
  end

  test "accepts buy limit orders", %{pid: pid} = _context do
    assert {:ok, _buy} = InstrumentProcessor.buy(pid, 2, 100)
    {:ok, buys, _sells} = InstrumentProcessor.books(pid)
    assert [%Buy{price: 2, quantity: 100, filled: 0}] = buys
  end

  test "accepts sell limit orders", %{pid: pid} = _context do
    assert {:ok, _sell} = InstrumentProcessor.sell(pid, 1, 50)
    {:ok, _buys, sells} = InstrumentProcessor.books(pid)
    assert [%Sell{price: 1, quantity: 50, filled: 0}] = sells
  end

  test "determines price", %{pid: pid} do
    {:ok, _sell} = InstrumentProcessor.sell(pid, 50, 1)
    {:ok, _sell} = InstrumentProcessor.sell(pid, 60, 1)
    {:ok, _sell} = InstrumentProcessor.sell(pid, 30, 1)
    {:ok, _sell} = InstrumentProcessor.sell(pid, 45, 1)

    assert {:ok, 30} = InstrumentProcessor.price(pid)
  end

  test "returns execution when buying if order is executed", %{pid: pid} do
    {:ok, _sell} = InstrumentProcessor.sell(pid, 120, 1)
    {:ok, _sell} = InstrumentProcessor.sell(pid, 130, 1)
    assert {:ok, %Execution{
      transactions: [
        %Transaction{
          buy: %Buy{quantity: 1, price: 130, filled: 1},
          sell: %Sell{quantity: 1, price: 120, filled: 1},
        }
      ]}} = InstrumentProcessor.buy(pid, 130, 1)
  end

  test "returns executions when buying if order is executed, and multiple sells were required for full execution", %{pid: pid} do
    {:ok, sell1} = InstrumentProcessor.sell(pid, 95, 5)
    {:ok, sell2} = InstrumentProcessor.sell(pid, 96, 2)
    {:ok, sell3} = InstrumentProcessor.sell(pid, 100, 5)
    assert {:ok, %Execution{
      transactions: transactions, trigger: buy }} = InstrumentProcessor.buy(pid, 100, 12)

    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 12, filled: 5},
      sell: %Sell{id: sell1.id, price: 95, quantity: 5, filled: 5}
    } in transactions
    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 12, filled: 7},
      sell: %Sell{id: sell2.id, price: 96, quantity: 2, filled: 2}
    } in transactions
    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 12, filled: 12},
      sell: %Sell{id: sell3.id, price: 100, quantity: 5, filled: 5}
    } in transactions
  end

  test "returns executions when selling if order is executed, and multiple buy were required for full execution", %{pid: pid} do
    {:ok, buy1} = InstrumentProcessor.buy(pid, 100, 10)
    {:ok, buy2} = InstrumentProcessor.buy(pid, 96, 5)
    assert {:ok, %Execution{
      transactions: transactions, trigger: sell}} = InstrumentProcessor.sell(pid, 90, 15)
    assert %Transaction{
      buy: %Buy{id: buy1.id, quantity: 10, price: 100, filled: 10},
      sell: %Sell{id: sell.id, quantity: 15, price: 90, filled: 10}
    } in transactions
    assert %Transaction{
      buy: %Buy{id: buy2.id, quantity: 5, price: 96, filled: 5},
      sell: %Sell{id: sell.id, quantity: 15, price: 90, filled: 15}
    } in transactions
  end

  test "multiple sells required to fill buy", %{pid: pid} do
    {:ok, sell1} = InstrumentProcessor.sell(pid, 98, 10)
    {:ok, sell2} = InstrumentProcessor.sell(pid, 99, 10)
    {:ok, sell3} = InstrumentProcessor.sell(pid, 100, 5)

    assert {:ok, %Execution{
      transactions: transactions, trigger: buy }} = InstrumentProcessor.buy(pid, 100, 25)
    assert length(transactions) == 3
    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 25, filled: 10},
      sell: %Sell{id: sell1.id, price: 98, quantity: 10, filled: 10}
    } in transactions
    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 25, filled: 20},
      sell: %Sell{id: sell2.id, price: 99, quantity: 10, filled: 10}
    } in transactions
    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 25, filled: 25},
      sell: %Sell{id: sell3.id, price: 100, quantity: 5, filled: 5}
    } in transactions
  end

  test "partial execution of buys", %{pid: pid} do
    {:ok, buy} = InstrumentProcessor.buy(pid, 100, 20)
    assert {:ok, %Execution{
      transactions: transactions, trigger: sell }} = InstrumentProcessor.sell(pid, 100, 10)

    assert %Transaction{
      buy: %Buy{id: buy.id, price: 100, quantity: 20, filled: 10},
      sell: %Sell{id: sell.id, price: 100, quantity: 10, filled: 10}
    } in transactions

    {:ok, buys, _sells} = InstrumentProcessor.books(pid)
    assert %Buy{id: buy.id, price: 100, quantity: 20, filled: 10} in buys
  end

  test "partial execution of sells", %{pid: pid} do
    {:ok, sell} = InstrumentProcessor.sell(pid, 50, 1000)
    assert {:ok, %Execution{
      transactions: transactions, trigger: buy }} = InstrumentProcessor.buy(pid, 50, 5)

    assert %Transaction{
      buy: %Buy{id: buy.id, price: 50, quantity: 5, filled: 5},
      sell: %Sell{id: sell.id, price: 50, quantity: 1000, filled: 5}
    } in transactions

    {:ok, _buys, sells} = InstrumentProcessor.books(pid)
    assert %Sell{id: sell.id, price: 50, quantity: 1000, filled: 5} in sells
  end

  test "cancels orders", %{pid: pid} do
    assert {:ok, buy} = InstrumentProcessor.buy(pid, 2, 100)
    assert {:ok, [^buy], _sells} = InstrumentProcessor.books(pid)

    assert :ok = InstrumentProcessor.cancel(pid, buy)
    {:ok, buys, _sells} = InstrumentProcessor.books(pid)
    assert buy not in buys
  end
end

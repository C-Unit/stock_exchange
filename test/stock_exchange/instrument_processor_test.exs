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
    assert :ok = InstrumentProcessor.buy(pid, 2, 100)
    {:ok, buys, _sells} = InstrumentProcessor.books(pid)
    assert [%Buy{price: 2, quantity: 100}] = buys
  end

  test "accepts sell limit orders", %{pid: pid} = _context do
    assert :ok = InstrumentProcessor.sell(pid, 1, 50)
    {:ok, _buys, sells} = InstrumentProcessor.books(pid)
    assert [%Sell{price: 1, quantity: 50}] = sells
  end

  test "determines price", %{pid: pid} do
    :ok = InstrumentProcessor.sell(pid, 50, 1)
    :ok = InstrumentProcessor.sell(pid, 60, 1)
    :ok = InstrumentProcessor.sell(pid, 30, 1)
    :ok = InstrumentProcessor.sell(pid, 45, 1)

    assert {:ok, 30} = InstrumentProcessor.price(pid)
  end

  test "returns execution when buying if order is executed", %{pid: pid} do
    :ok = InstrumentProcessor.sell(pid, 120, 1)
    :ok = InstrumentProcessor.sell(pid, 130, 1)
    assert {:ok, %Execution{
      transactions: [
        %Transaction{
          buy: %Buy{quantity: 1, price: 130},
          sell: %Sell{quantity: 1, price: 120}
        }
      ]}} = InstrumentProcessor.buy(pid, 130, 1)
  end

  test "returns execution when selling if order is executed", %{pid: pid} do
    :ok = InstrumentProcessor.buy(pid, 120, 6)
    :ok = InstrumentProcessor.buy(pid, 135, 1)
    assert {:ok, %Execution{
      transactions: [
        %Transaction{
          buy: %Buy{quantity: 1, price: 135},
          sell: %Sell{quantity: 1, price: 130}
        }
      ]}} = InstrumentProcessor.sell(pid, 130, 1)
  end

  test "returns executions when buying if order is executed, and multiple sells were required for full execution"
  test "returns executions when selling if order is executed, and multiple buy were required for full execution"
end

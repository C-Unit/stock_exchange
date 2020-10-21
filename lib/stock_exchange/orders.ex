defmodule StockExchange.Orders do
  defmodule Buy, do: defstruct [:price, :quantity, :filled]
  defmodule Sell, do: defstruct [:price, :quantity, :filled]

end

defmodule StockExchange.Orders do
  defmodule Buy, do: defstruct [:price, :quantity]
  defmodule Sell, do: defstruct [:price, :quantity]

end

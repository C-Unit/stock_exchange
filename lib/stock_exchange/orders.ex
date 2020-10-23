defmodule StockExchange.Orders do
  defmodule Buy, do: defstruct [:price, :quantity, filled: 0]
  defmodule Sell, do: defstruct [:price, :quantity, filled: 0]

end

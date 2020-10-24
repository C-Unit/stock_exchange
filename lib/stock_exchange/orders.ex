defmodule StockExchange.Orders do
  defmodule Buy, do: defstruct [:id, :price, :quantity, filled: 0]
  defmodule Sell, do: defstruct [:id, :price, :quantity, filled: 0]

end

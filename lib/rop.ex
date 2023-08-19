# https://gist.github.com/zabirauf/17ced02bdf9829b6956e
# https://github.com/remiq/railway-oriented-programming-elixir

defmodule Rop do
  defmacro __using__(_) do
    quote do
      import Rop
    end
  end


  @doc ~s"""
  Extracts the value from a tagged tuple like {:ok, value}
  Raises the value from a tagged tuple like {:error, value}
  Raise the arguments else

  For example:
      iex> unwrap({:ok, 1})
      1

      iex> unwrap({:error, "some"})
      ** (RuntimeError) some

      iex> unwrap({:anything, "some"})
      ** (ArgumentError) raise/1 and reraise/2 expect a module name, string or exception as the first argument, got: {:anything, \"some\"}
  """
  def unwrap({:ok, x}), do: x
  def unwrap({:error, x}), do: raise x
  def unwrap(x), do: raise x

  @doc ~s"""
    Wraps the value in an ok tagged tuple like {:ok, value}
  """
  def ok({:ok, x}), do: {:ok, x}
  def ok({:error, x}), do: {:error, x}
  def ok(x), do: {:ok, x}

  @doc ~s"""
    Wraps the value in an error tagged tuple like {:error, value}
  """
  def err(x), do: {:error, x}

  @doc ~s"""
    No need to stop pipelining in case of an error somewhere in the middle

    Example:
      iex> inc = fn(x)-> {:ok, x+1} end
      iex> 1 |> (inc).() >>> (inc).()
      {:ok, 3}
  """
  defmacro left >>> right do
    quote do
      (fn ->
        case unquote(left) do
          {:ok, x} -> x |> unquote(right)
          {:error, _} = expr -> expr
        end
      end).()
    end
  end

  @doc ~s"""
    Wraps a simple function to return a tagged tuple with `:ok` to comply to the protocol `{:ok, result}`

    Example:
      iex> 1 |> Integer.to_string
      "1"
      iex> 1 |> bind(Integer.to_string)
      {:ok, "1"}


      iex> inc = fn(x)-> x+1 end
      iex> 1 |> bind((inc).()) >>> (inc).()
      3
      iex> 1 |> bind((inc).()) >>> bind((inc).())
      {:ok, 3}
  """
  defmacro bind(args, func) do
    quote do
      (fn ->
        {:ok, unquote(args) |> unquote(func)}
      end).()
    end
  end

  @doc ~s"""
    Wraps raising functions to return a tagged tuple `{:error, ErrorMessage}` to comply with the protocol

    Example:
      iex> r = fn(_)-> raise "some" end
      iex> inc = fn(x)-> x + 1 end
      iex> 1 |> bind((inc).()) >>> try_catch((r).()) >>> bind((inc).())
      {:error, %RuntimeError{message: "some"}}
  """
  defmacro try_catch(args, func) do
    quote do
      (fn ->
        try do
          {:ok, unquote(args) |> unquote(func)}
        rescue
          e -> {:error, e}
        end
      end).()
    end
  end



  @doc ~s"""
    Like a similar Unix utility it does some work and returns the input.
    See [tee (command), Unix](https://en.wikipedia.org/wiki/Tee_(command)).

    Example:
      iex> inc = fn(x)-> IO.inspect(x); {:ok, x + 1} end
      iex> 1 |> tee((inc).()) >>> tee((inc).()) >>> tee((inc).())
      {:ok, 1}
  """
  defmacro tee(args, func) do
    quote do
      (fn ->
        unquoted_args = unquote(args)
        unquoted_args |> unquote(func)
        {:ok, unquoted_args}
      end).()
    end
  end

  @doc ~s"""
    Similar to `tee`, but propagates any error response from the side effect.

    Example:
      iex> inc = fn(x)-> IO.inspect(x); {:ok, x + 1} end
      iex> 1 |> error_tee((inc).()) >>> error_tee((inc).()) >>> error_tee((inc).())
      {:ok, 1}
      iex> inc = fn(x)-> IO.inspect(x); {:error, :bad} end
      iex> 1 |> error_tee((inc).()) >>> error_tee((inc).()) >>> error_tee((inc).())
      {:error, :bad}
  """
  defmacro error_tee(args, func) do
    quote do
      (fn ->
        unquoted_args = unquote(args)
        case unquoted_args |> unquote(func) do
          {:error, _} = expr -> expr
          _ -> {:ok, unquoted_args}
        end
      end).()
    end
  end
end

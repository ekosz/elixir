defprotocol Enum.Iterator do
  @moduledoc """
  This is the protocol used by the `Enum` module.
  Usually, when you invoke a function in the module `Enum`,
  the first argument passed to `Enum` is a collection which
  is forwarded to this protocol in order to retrieve information
  on how to iterate the collection. That said, when:

      Enum.map [1,2,3], &1 * 2

  Is invoked, it invokes `Enum.Iterator.iterator([1,2,3])`
  which returns all the information required by Enum.
  Read each function documentation below for more information.
  """

  @only [List, Record, Function]

  @doc """
  Iteration in Elixir happens with the help of a iterator
  function. Every time this function is called, it must
  return a tuple with two elements. The first element
  is the next item and the second can be any Elixir term
  which the function is going to receive as argument the
  next time it is invoked.

  When there are no more items to be iterated, the function
  must return the atom `:stop`.

  In order to retrieve this iterator function, Elixir invokes
  `Enum.Iterator.iterator(collection)` which should return a
  tuple with two elements: the first element is the iterator
  function and the second is the first step of iteration.

  As an example, here is the implementation of iterator for lists:

      def iterator(list),   do: { iterate(&1), iterate(list) }
      defp iterate([h|t]),  do: { h, t }
      defp iterate([]),     do: :stop

  ## Iterating lists

  If a data structure needs to be converted to a list in order
  to be iterated, the iterator function can simply return the
  list and the Enum module will be able to take over the list
  and retrieve the proper iterator function.
  """
  def iterator(collection)

  @doc """
  The function used to retrieve the collection size.
  """
  def count(collection)
end

defprotocol Enum.OrdIterator do
  @moduledoc """
  This protocol is invoked by some functions in Enum which
  requires an ordered collection to function correctly. For
  instance, `Enum.split_with/2`, `Enum.take_while` all rely
  on this protocol.

  An ordered collection does not mean the items are ordered
  according to the Elixir ordering but simply that any two
  distinct instances of the same collection with exactly
  the same items always yield the same order when iterated.
  """

  @only [List, Record]

  @doc """
  Must return a tuple under the same conditions as
  `Enum.Iterator.iterator`.
  """
  def iterator(collection)

  @doc """
  On each step, the iterator function returned by `iterator/1`
  returns a tuple with two elements. This function receives
  those two elements as a tuple and must return a list back.

  This is used in order to quicky return a list from any point
  during iteration. For example, consider the function `Enum.drop`.
  `Enum.drop collection, 3` should drop 3 items and return a list
  back. While we could loop over the remaining items to get a list
  back, this function is invoked allowing us to get a result
  back without a need to loop the remaining items.
  """
  def to_list({ current, next }, iterator)
end

defmodule Enum do
  require Enum.Iterator, as: I
  require Enum.OrdIterator, as: O

  @moduledoc """
  Provides a set of algorithms that enumerate over collections according to the
  `Enum.Iterator` protocol. Most of the functions in this module have two
  flavours. If a given collection implements the mentioned protocol (like
  list, for instance), you can do:

      Enum.map [1,2,3], fn(x) -> x * 2 end

  Depending on the type of the collection, the user-provided function will
  accept a certain type of argument. For dicts, the argument is always a
  `{ key, value }` tuple.
  """

  @doc """
  Invokes the given `fun` for each item in the `collection` and returns true if
  each invocation returns true as well, otherwise it shirt-circuits and returns
  false.

  ## Examples

      Enum.all? [2,4,6], fn(x) -> rem(x, 2) == 0 end
      #=> true

      Enum.all? [2,3,4], fn(x) -> rem(x, 2) == 0 end
      #=> false

  If no function is given, it defaults to checking if
  all items in the collection evaluate to true.

      Enum.all? [1,2,3]   #=> true
      Enum.all? [1,nil,3] #=> false

  """
  def all?(collection, fun // fn(x) -> x end)

  def all?(collection, fun) when is_list(collection) do
    do_all?(collection, fun)
  end

  def all?(collection, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_all?(pointer, iterator, fun)
      list when is_list(list) ->
        do_all?(list, fun)
    end
  end

  @doc """
  Invokes the given `fun` for each item in the `collection` and returns true if
  at least one invocation returns true. Returns false otherwise.

  ## Examples

      Enum.any? [2,4,6], fn(x) -> rem(x, 2) == 1 end
      #=> false

      Enum.any? [2,3,4], fn(x) -> rem(x, 2) == 1 end
      #=> true

  If no function is given, it defaults to checking if
  at least one item in the collection evaluates to true.

      Enum.any? [false,false,false] #=> false
      Enum.any? [false,true,false]  #=> true

  """
  def any?(collection, fun // fn(x) -> x end)

  def any?(collection, fun) when is_list(collection) do
    do_any?(collection, fun)
  end

  def any?(collection, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_any?(pointer, iterator, fun)
      list when is_list(list) ->
        do_any?(list, fun)
    end
  end

  @doc """
  Returns the collection size.

  ## Examples

      Enum.count [1,2,3] #=> 3

  """
  def count(collection) do
    I.count(collection)
  end

  @doc """
  Drops the first `count` items from the collection. Expects an ordered
  collection.

  ## Examples

      Enum.drop [1,2,3], 2  #=> [3]
      Enum.drop [1,2,3], 10 #=> []
      Enum.drop [1,2,3], 0  #=> [1,2,3]

  """
  def drop(collection, count) do
    elem split(collection, count), 2
  end

  @doc """
  Drops items at the beginning of `collection` while `fun` returns true.
  Expects an ordered collection.

  ## Examples

      Enum.drop_while [1,2,3,4,5], fn(x) -> x < 3 end
      #=> [3,4,5]
  """
  def drop_while(collection, fun) when is_list(collection) do
    do_drop_while(collection, fun)
  end

  def drop_while(collection, fun) do
    case O.iterator(collection) do
      { iterator, pointer } ->
        module = O.__impl_for__!(collection)
        do_drop_while(pointer, iterator, fun, module)
      list when is_list(list) ->
        do_drop_while(list, fun)
    end
  end

  @doc """
  Invokes the given `fun` for each item in the `collection`.
  Returns the `collection` itself.

  ## Examples

      Enum.each ['some', 'example'], fn(x) -> IO.puts x end

  """
  def each(collection, fun) when is_list(collection) do
    :lists.foreach(fun, collection)
    :ok
  end

  def each(collection, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_each(pointer, iterator, fun)
        :ok
      list when is_list(list) ->
        each(list, fun)
    end
  end

  @doc """
  Returns true if the collection is empty, otherwise false.

  ## Examples

      Enum.empty? []      #=> true
      Enum.empty? [1,2,3] #=> false

  """
  def empty?(collection) when is_list(collection) do
    collection == []
  end

  def empty?(collection) do
    case I.iterator(collection) do
      { _iterator, pointer }  -> pointer === :stop
      list when is_list(list) -> list == []
    end
  end

  @doc """
  Filters the collection, i.e. returns only those elements
  for which `fun` returns true.

  ## Examples

      Enum.filter [1, 2, 3], fn(x) -> rem(x, 2) == 0 end
      #=> [2]

  """
  def filter(collection, fun) when is_list(collection) do
    lc item inlist collection, fun.(item), do: item
  end

  def filter(collection, fun) do
    case I.iterator(collection) do
      { iterator, pointer }  ->
        do_filter(pointer, iterator, fun)
      list when is_list(list) ->
        filter(list, fun)
    end
  end

  @doc """
  Filters the collection and maps its values in one pass.

  ## Examples

      Enum.filter_map [1, 2, 3], fn(x) -> rem(x, 2) == 0 end, &1 * 2
      #=> [4]

  """
  def filter_map(collection, filter, mapper) when is_list(collection) do
    lc item inlist collection, filter.(item), do: mapper.(item)
  end

  def filter_map(collection, filter, mapper) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_filter_map(pointer, iterator, filter, mapper)
      list when is_list(list) ->
        filter_map(list, filter, mapper)
    end
  end

  @doc """
  Returns the first item for which `fun` returns a truthy value. If no such
  item is found, returns `ifnone`.

  ## Examples

      Enum.find [2,4,6], fn(x) -> rem(x, 2) == 1 end
      #=> nil

      Enum.find [2,4,6], 0, fn(x) -> rem(x, 2) == 1 end
      #=> 0

      Enum.find [2,3,4], fn(x) -> rem(x, 2) == 1 end
      #=> 3

  """
  def find(collection, ifnone // nil, fun)

  def find(collection, ifnone, fun) when is_list(collection) do
    do_find(collection, ifnone, fun)
  end

  def find(collection, ifnone, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_find(pointer, iterator, ifnone, fun)
      list when is_list(list) ->
        do_find(list, ifnone, fun)
    end
  end

  @doc """
  Similar to find, but returns the value of the function
  invocation instead of the element itself.

    ## Examples

        Enum.find_value [2,4,6], fn(x) -> rem(x, 2) == 1 end
        #=> nil

        Enum.find_value [2,3,4], fn(x) -> rem(x, 2) == 1 end
        #=> true

  """
  def find_value(collection, ifnone // nil, fun)

  def find_value(collection, ifnone, fun) when is_list(collection) do
    do_find_value(collection, ifnone, fun)
  end

  def find_value(collection, ifnone, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_find_value(pointer, iterator, ifnone, fun)
      list when is_list(list) ->
        do_find_value(list, ifnone, fun)
    end
  end

  @doc """
  Similar to find, but returns the index (count starts with 1)
  of the item instead of the element itself.

  Expects an ordered collection.

    ## Examples

        Enum.find_index [2,4,6], fn(x) -> rem(x, 2) == 1 end
        #=> nil

        Enum.find_index [2,3,4], fn(x) -> rem(x, 2) == 1 end
        #=> 2

  """
  def find_index(collection, fun) when is_list(collection) do
    do_find_index(collection, 1, fun)
  end

  def find_index(collection, fun) do
    case O.iterator(collection) do
      { iterator, pointer } ->
        do_find_index(pointer, iterator, 1, fun)
      list when is_list(list) ->
        do_find_index(list, 1, fun)
    end
  end

  @doc """
  Returns the first item in the collection or nil otherwise.

  ## Examples

      Enum.first []      #=> nil
      Enum.first [1,2,3] #=> 1

  """
  def first([]),    do: nil
  def first([h|_]), do: h

  def first(collection) do
    case O.iterator(collection) do
      { _iterator, { h, _ } } -> h
      { _iterator, :stop }    -> nil
      list when is_list(list) -> first(list)
    end
  end

  @doc """
  Joins the given `collection` according to `joiner`.
  Joiner can be either a binary or a list and the
  result will be of the same type as joiner. If
  joiner is not passed at all, it defaults to an
  empty binary.

  All items in the collection must be convertible
  to binary, otherwise an error is raised.

  ## Examples

      Enum.join([1,2,3])        #=> "123"
      Enum.join([1,2,3], " = ") #=> "1 = 2 = 3"
      Enum.join([1,2,3], ' = ') #=> '1 = 2 = 3'

  """
  def join(collection, joiner // "")

  def join(collection, joiner) when is_list(joiner) do
    binary_to_list join(collection, list_to_binary(joiner))
  end

  def join(collection, joiner) when is_list(collection) and is_binary(joiner) do
    do_join(collection, joiner, nil)
  end

  def join(collection, joiner) when is_binary(joiner) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_join(pointer, iterator, joiner, nil)
      list when is_list(list) ->
        do_join(list, joiner, nil)
    end
  end

  @doc """
  Returns a new collection, where each item is the result
  of invoking `fun` on each corresponding item of `collection`.
  For dicts, the function accepts a key-value tuple.

  ## Examples

      Enum.map [1, 2, 3], fn(x) -> x * 2 end
      #=> [2, 4, 6]

      Enum.map [a: 1, b: 2], fn({k, v}) -> { k, -v } end
      #=> [a: -1, b: -2]

  """
  def map(collection, fun) when is_list(collection) do
    lc item inlist collection, do: fun.(item)
  end

  def map(collection, fun) do
    case I.iterator(collection) do
      { iterator, pointer }  ->
        do_map(pointer, iterator, fun)
      list when is_list(list) ->
        map(list, fun)
    end
  end

  @doc """
  Maps and joins the given `collection` in one pass.
  Joiner can be either a binary or a list and the
  result will be of the same type as joiner. If
  joiner is not passed at all, it defaults to an
  empty binary.

  All items in the collection must be convertible
  to binary, otherwise an error is raised.

  ## Examples

      Enum.map_join([1,2,3], &1 * 2)        #=> "246"
      Enum.map_join([1,2,3], &1 * 2, " = ") #=> "2 = 4 = 6"
      Enum.map_join([1,2,3], &1 * 2, ' = ') #=> '2 = 4 = 6'

  """
  def map_join(collection, joiner // "", mapper)

  def map_join(collection, joiner, mapper) when is_list(joiner) do
    binary_to_list map_join(collection, list_to_binary(joiner), mapper)
  end

  def map_join(collection, joiner, mapper) when is_list(collection) and is_binary(joiner) do
    do_map_join(collection, mapper, joiner, nil)
  end

  def map_join(collection, joiner, mapper) when is_binary(joiner) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_map_join(pointer, iterator, mapper, joiner, nil)
      list when is_list(list) ->
        do_map_join(list, mapper, joiner, nil)
    end
  end

  @doc """
  Invokes the given `fun` for each item in the `collection`
  while also keeping an accumulator. Returns a tuple where
  the first element is the mapped collection and the second
  one is the final accumulator.

  For dicts, the first tuple element has to be a { key, value }
  tuple itself.

  ## Examples

      Enum.map_reduce [1, 2, 3], 0, fn(x, acc) -> { x * 2, x + acc } end
      #=> { [2, 4, 6], 6 }

  """
  def map_reduce(collection, acc, f) when is_list(collection) do
    :lists.mapfoldl(f, acc, collection)
  end

  def map_reduce(collection, acc, fun) do
    case I.iterator(collection) do
      { iterator, pointer }  ->
        do_map_reduce(pointer, iterator, [], acc, fun)
      list when is_list(list) ->
        map_reduce(list, acc, fun)
    end
  end

  @doc """
  Finds the element at the nth index. Returns nil in case
  the given index is outside the range of the collection.

  Expects an ordered collection.

    ## Examples

        Enum.nth! [2,4,6], 1 #=> 2
        Enum.nth! [2,4,6], 3 #=> 6
        Enum.nth! [2,4,6], 5 #=> raises Enum.OutOfBoundsError

  """
  def nth!(collection, n) when is_list(collection) and n > 0 do
    do_nth!(collection, n)
  end

  def nth!(collection, n) when n > 0 do
    case O.iterator(collection) do
      { iterator, pointer } ->
        do_nth!(pointer, iterator, n)
      list when is_list(list) ->
        do_nth!(list, n)
    end
  end

  @doc """
  Partitions `collection` into two where the first one contains elements
  for which `fun` returns a truthy value, and the second one -- for which `fun`
  returns false or nil.

  ## Examples

      Enum.partition [1, 2, 3], fn(x) -> rem(x, 2) == 0 end
      #=> { [2], [1,3] }

  """
  def partition(collection, fun) when is_list(collection) do
    do_partition(collection, fun, [], [])
  end

  def partition(collection, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_partition(pointer, iterator, fun, [], [])
      list when is_list(list) ->
        do_partition(list, fun, [], [])
    end
  end

  @doc """
  Invokes `fun` for each element in the collection passing the accumulator
  `acc` and the element as arguments. The return value is stored in `acc`.
  Returns the accumulator.

  ## Examples

      Enum.reduce [1, 2, 3], 0, fn(x, acc) -> x + acc end
      #=> 6

  """
  def reduce(collection, acc, fun) when is_list(collection) do
    :lists.foldl(fun, acc, collection)
  end

  def reduce(collection, acc, fun) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_reduce(pointer, iterator, acc, fun)
      list when is_list(list) ->
        reduce(list, acc, fun)
    end
  end

  @doc """
  Sorts the collection according to the quick sort algorithm.

  ## Examples

      Enum.qsort [3,2,1] #=> [1,2,3]

  """
  def qsort(collection) when is_list(collection) do
    do_list_qsort(collection, [])
  end

  def qsort(collection) do
    case I.iterator(collection) do
      { iterator, pointer } ->
        do_qsort(pointer, iterator, [])
      list when is_list(list) ->
        qsort(list)
    end
  end

  @doc """
  Splits the enumerable into two collections, leaving `count` elements in the
  first one. Expects an ordered collection.

  ## Examples

      Enum.split [1,2,3], 2  #=> { [1,2], [3] }
      Enum.split [1,2,3], 10 #=> { [1,2,3], [] }
      Enum.split [1,2,3], 0  #=> { [], [1,2,3] }

  """
  def split(collection, count) when is_list(collection) and count >= 0 do
    do_split(collection, count, [])
  end

  def split(collection, count) when count >= 0 do
    case O.iterator(collection) do
      { iterator, pointer } ->
        module = O.__impl_for__!(collection)
        do_split(pointer, iterator, count, [], module)
      list when is_list(list) ->
        do_split(list, count, [])
    end
  end

  @doc """
  Splits `collection` at the first element, for which `fun` returns true.
  Expects an ordered collection.

  ## Examples

      Enum.split_with [1,2,3,4], fn x -> x == 2 end
      #=> { [1], [2, 3, 4] }
  """
  def split_with(collection, fun) when is_list(collection) do
    do_split_with(collection, fun, [])
  end

  def split_with(collection, fun) do
    case O.iterator(collection) do
      { iterator, pointer } ->
        module = O.__impl_for__!(collection)
        do_split_with(pointer, iterator, fun, [], module)
      list when is_list(list) ->
        do_split_with(list, fun, [])
    end
  end

  @doc """
  Takes the first `count` items from the collection. Expects an ordered
  collection.

  ## Examples

      Enum.take [1,2,3], 2  #=> [1,2]
      Enum.take [1,2,3], 10 #=> [1,2,3]
      Enum.take [1,2,3], 0  #=> []

  """
  def take(collection, count) do
    elem split(collection, count), 1
  end

  @doc """
  Takes the items at the beginning of `collection` while `fun` returns true.
  Expects an ordered collection.

  ## Examples

      Enum.take_while [1,2,3], fn(x) -> x < 3 end
      #=> [1, 2]

  """
  def take_while(collection, fun) when is_list(collection) do
    do_take_while(collection, fun)
  end

  def take_while(collection, fun) do
    case O.iterator(collection) do
      { iterator, pointer } ->
        do_take_while(pointer, iterator, fun)
      list when is_list(list) ->
        do_take_while(list, fun)
    end
  end

  @doc """
  Iterates the given function n times, passing values from 1
  to n.

  ## Examples

      Enum.times 3, fn(x) -> IO.inspect x end
      1
      2
      3

  """
  def times(times, function) when times >= 0 do
    case is_function(function, 0) do
      true ->
        do_times_0(times, 1, function)
      _ ->
        do_times_1(times, 1, function)
    end
    times
  end

  @doc """
  Iterates the given function n times, passing values from 1
  to n. Also has an accumulator similar to reduce to store the
  value between computations.

  ## Examples

      Enum.times 5, 0, fn(x, acc) -> acc + x end
      #=> 15

  """
  def times(times, acc, function) when times >= 0 do
    do_times_2(times, 1, function, acc)
  end

  ## Implementations

  ## all?

  defp do_all?([h|t], fun) do
    if fun.(h) do
      do_all?(t, fun)
    else
      false
    end
  end

  defp do_all?([], _) do
    true
  end

  defp do_all?({ h, next }, iterator, fun) do
    if fun.(h) do
      do_all?(iterator.(next), iterator, fun)
    else
      false
    end
  end

  defp do_all?(:stop, _, _) do
    true
  end

  ## any?

  defp do_any?([h|t], fun) do
    if fun.(h) do
      true
    else
      do_any?(t, fun)
    end
  end

  defp do_any?([], _) do
    false
  end

  defp do_any?({ h, next }, iterator, fun) do
    if fun.(h) do
      true
    else
      do_any?(iterator.(next), iterator, fun)
    end
  end

  defp do_any?(:stop, _, _) do
    false
  end

  ## drop_while

  defp do_drop_while([h|t], fun) do
    if fun.(h) do
      do_drop_while(t, fun)
    else
      [h|t]
    end
  end

  defp do_drop_while([], _) do
    []
  end

  defp do_drop_while({ h, next } = extra, iterator, fun, module) do
    if fun.(h) do
      do_drop_while(iterator.(next), iterator, fun, module)
    else
      module.to_list(extra, iterator)
    end
  end

  defp do_drop_while(:stop, _, _, _) do
    []
  end

  ## find

  defp do_find([h|t], ifnone, fun) do
    if fun.(h) do
      h
    else
      do_find(t, ifnone, fun)
    end
  end

  defp do_find([], ifnone, _) do
    ifnone
  end

  defp do_find({ h, next }, iterator, ifnone, fun) do
    if fun.(h) do
      h
    else
      do_find(iterator.(next), iterator, ifnone, fun)
    end
  end

  defp do_find(:stop, _, ifnone, _) do
    ifnone
  end

  ## find_value

  defp do_find_value([h|t], ifnone, fun) do
    fun.(h) || do_find_value(t, ifnone, fun)
  end

  defp do_find_value([], ifnone, _) do
    ifnone
  end

  defp do_find_value({ h, next }, iterator, ifnone, fun) do
    fun.(h) || do_find_value(iterator.(next), iterator, ifnone, fun)
  end

  defp do_find_value(:stop, _, ifnone, _) do
    ifnone
  end

  ## find_index

  defp do_find_index([h|t], counter, fun) do
    if fun.(h) do
      counter
    else
      do_find_index(t, counter + 1, fun)
    end
  end

  defp do_find_index([], _, _) do
    nil
  end

  defp do_find_index({ h, next }, iterator, counter, fun) do
    if fun.(h) do
      counter
    else
      do_find_index(iterator.(next), iterator, counter + 1, fun)
    end
  end

  defp do_find_index(:stop, _, _, _) do
    nil
  end

  ## each

  defp do_each({ h, next }, iterator, fun) do
    fun.(h)
    do_each(iterator.(next), iterator, fun)
  end

  defp do_each(:stop, _, _) do
    []
  end

  ## filter

  defp do_filter({ h, next }, iterator, fun) do
    if fun.(h) do
      [h|do_filter(iterator.(next), iterator, fun)]
    else
      do_filter(iterator.(next), iterator, fun)
    end
  end

  defp do_filter(:stop, _, _) do
    []
  end

  ## filter_map

  defp do_filter_map({ h, next }, iterator, filter, mapper) do
    if filter.(h) do
      [mapper.(h)|do_filter_map(iterator.(next), iterator, filter, mapper)]
    else
      do_filter_map(iterator.(next), iterator, filter, mapper)
    end
  end

  defp do_filter_map(:stop, _, _, _) do
    []
  end

  ## nth

  defp do_nth!([h|_], 1), do: h
  defp do_nth!([_|t], n), do: do_nth!(t, n - 1)
  defp do_nth!([], _),    do: raise Enum.OutOfBoundsError

  defp do_nth!({ h, _next }, _iterator, 1), do: h
  defp do_nth!({ _, next }, iterator, n),   do: do_nth!(iterator.(next), iterator, n - 1)
  defp do_nth!(:stop, _iterator, _),        do: raise Enum.OutOfBoundsError

  ## reduce

  defp do_reduce({ h, next }, iterator, acc, fun) do
    do_reduce(iterator.(next), iterator, fun.(h, acc), fun)
  end

  defp do_reduce(:stop, _, acc, _) do
    acc
  end

  ## split_with

  defp do_split_with([h|t], fun, acc) do
    if fun.(h) do
      do_split_with(t, fun, [h|acc])
    else
      { List.reverse(acc), [h|t] }
    end
  end

  defp do_split_with([], _, acc) do
    { List.reverse(acc), [] }
  end

  defp do_split_with({ h, next } = extra, iterator, fun, acc, module) do
    if fun.(h) do
      do_split_with(iterator.(next), iterator, fun, [h|acc], module)
    else
      { List.reverse(acc), module.to_list(extra, iterator) }
    end
  end

  defp do_split_with(:stop, _, _, acc, _module) do
    { List.reverse(acc), [] }
  end

  ## join

  defp do_join([h|t], joiner, nil) do
    do_join(t, joiner, to_binary(h))
  end

  defp do_join([h|t], joiner, acc) do
    acc = << acc | :binary, joiner | :binary, to_binary(h) | :binary >>
    do_join(t, joiner, acc)
  end

  defp do_join([], _joiner, acc) do
    acc || ""
  end

  defp do_join({ h, next }, iterator, joiner, nil) do
    do_join(iterator.(next), iterator, joiner, to_binary(h))
  end

  defp do_join({ h, next }, iterator, joiner, acc) do
    acc = << acc | :binary, joiner | :binary, to_binary(h) | :binary >>
    do_join(iterator.(next), iterator, joiner, acc)
  end

  defp do_join(:stop, _, _joiner, acc) do
    acc || ""
  end

  ## map join

  defp do_map_join([h|t], mapper, joiner, nil) do
    do_map_join(t, mapper, joiner, to_binary(mapper.(h)))
  end

  defp do_map_join([h|t], mapper, joiner, acc) do
    acc = << acc | :binary, joiner | :binary, to_binary(mapper.(h)) | :binary >>
    do_map_join(t, mapper, joiner, acc)
  end

  defp do_map_join([], _mapper, _joiner, acc) do
    acc || ""
  end

  defp do_map_join({ h, next }, iterator, mapper, joiner, nil) do
    do_map_join(iterator.(next), iterator, mapper, joiner, to_binary(mapper.(h)))
  end

  defp do_map_join({ h, next }, iterator, mapper, joiner, acc) do
    acc = << acc | :binary, joiner | :binary, to_binary(mapper.(h)) | :binary >>
    do_map_join(iterator.(next), iterator, mapper, joiner, acc)
  end

  defp do_map_join(:stop, _, _mapper, _joiner, acc) do
    acc || ""
  end

  ## map

  defp do_map({ h, next }, iterator, fun) do
    [fun.(h)|do_map(iterator.(next), iterator, fun)]
  end

  defp do_map(:stop, _, _) do
    []
  end

  ## map_reduce

  defp do_map_reduce({ h, next }, iterator, list_acc, acc, f) do
    { result, acc } = f.(h, acc)
    do_map_reduce(iterator.(next), iterator, [result|list_acc], acc, f)
  end

  defp do_map_reduce(:stop, _, list_acc, acc, _f) do
    { List.reverse(list_acc), acc }
  end

  ## partition

  defp do_partition([h|t], fun, acc1, acc2) do
    if fun.(h) do
      do_partition(t, fun, [h|acc1], acc2)
    else
      do_partition(t, fun, acc1, [h|acc2])
    end
  end

  defp do_partition([], _, acc1, acc2) do
    { List.reverse(acc1), List.reverse(acc2) }
  end

  defp do_partition({ h, next }, iterator, fun, acc1, acc2) do
    if fun.(h) do
      do_partition(iterator.(next), iterator, fun, [h|acc1], acc2)
    else
      do_partition(iterator.(next), iterator, fun, acc1, [h|acc2])
    end
  end

  defp do_partition(:stop, _, _, acc1, acc2) do
    { List.reverse(acc1), List.reverse(acc2) }
  end

  ## qsort (lists)

  defp do_list_qsort([], acc) do
    acc
  end

  defp do_list_qsort([h|t], acc) do
    do_list_qsort_part(h, t, {[], [h], []}, acc)
  end

  defp do_list_qsort_part(_, [], { l, e, g }, acc) do
    do_list_qsort(l, e ++ do_list_qsort(g, acc))
  end

  defp do_list_qsort_part(x, [h|t], { l, e, g }, acc) do
    cond do
      h < x ->
        do_list_qsort_part(x, t, { [h|l], e, g }, acc)
      h > x ->
        do_list_qsort_part(x, t, { l, e, [h|g] }, acc)
      true ->
        do_list_qsort_part(x, t, { l, [h|e], g }, acc)
    end
  end

  ## qsort (iterator)

  defp do_qsort({ h, next }, iterator, acc) do
    do_qsort_part(h, iterator.(next), iterator, {[], [h], []}, acc)
  end

  defp do_qsort(:stop, _iterator, acc) do
    acc
  end

  defp do_qsort_part(_, :stop, _iterator, { l, e, g }, acc) do
    do_list_qsort(l, e ++ do_list_qsort(g, acc))
  end

  defp do_qsort_part(x, { h, next }, iterator, { l, e, g }, acc) do
    cond do
      h < x ->
        do_qsort_part(x, iterator.(next), iterator, { [h|l], e, g }, acc)
      h > x ->
        do_qsort_part(x, iterator.(next), iterator, { l, e, [h|g] }, acc)
      true ->
        do_qsort_part(x, iterator.(next), iterator, { l, [h|e], g }, acc)
    end
  end

  ## split

  defp do_split([h|t], counter, acc) when counter > 0 do
    do_split(t, counter - 1, [h|acc])
  end

  defp do_split(list, 0, acc) do
    { List.reverse(acc), list }
  end

  defp do_split([], _, acc) do
    { List.reverse(acc), [] }
  end

  defp do_split({ h, next }, iterator, counter, acc, module) when counter > 0 do
    do_split(iterator.(next), iterator, counter - 1, [h|acc], module)
  end

  defp do_split(extra, iterator, 0, acc, module) do
    { List.reverse(acc), module.to_list(extra, iterator) }
  end

  defp do_split(:stop, _, _, acc, _module) do
    { List.reverse(acc), [] }
  end

  ## take_while

  defp do_take_while([h|t], fun) do
    if fun.(h) do
      [h|do_take_while(t, fun)]
    else
      []
    end
  end

  defp do_take_while([], _) do
    []
  end

  defp do_take_while({ h, next }, iterator, fun) do
    if fun.(h) do
      [h|do_take_while(iterator.(next), iterator, fun)]
    else
      []
    end
  end

  defp do_take_while(:stop, _, _) do
    []
  end

  ## times

  defp do_times_0(limit, counter, _function) when counter > limit do
  end

  defp do_times_0(limit, counter, function) do
    function.()
    do_times_0(limit, 1 + counter, function)
  end

  defp do_times_1(limit, counter, _function) when counter > limit do
  end

  defp do_times_1(limit, counter, function) do
    function.(counter)
    do_times_1(limit, 1 + counter, function)
  end

  defp do_times_2(limit, counter, _function, acc) when counter > limit do
    acc
  end

  defp do_times_2(limit, counter, function, acc) do
    new_acc = function.(counter, acc)
    do_times_2(limit, 1 + counter, function, new_acc)
  end
end

defimpl Enum.Iterator, for: List do
  def iterator(list),  do: list
  def count(list),     do: length(list)
end

defimpl Enum.OrdIterator, for: List do
  def iterator(list),          do: list
  def to_list({ h, next }, _), do: [h|next]
end

defimpl Enum.Iterator, for: Function do
  def iterator(function) do
    { function, function.(:start) }
  end

  def count(function) do
    do_count(function.(:start), function, 0)
  end

  defp do_count({ _, next }, function, acc) do
    do_count(function.(next), function, acc + 1)
  end

  defp do_count(:stop, _, acc) do
    acc
  end
end

defimpl Enum.OrdIterator, for: Function do
  def iterator(function) do
    { function, function.(:start) }
  end

  def to_list({ h, next }, function) do
    [h|to_list(function.(next), function)]
  end

  def to_list(:stop, _function) do
    []
  end
end
use "cli"
use "collections"
use "random"

primitive ConcsllConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("concsll", "", [
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 20."
          where short' = 'w', default' = 20
        )
        OptionSpec.u64(
          "messages",
          "The number of messages per worker. Defaults to 8000."
          where short' = 'm', default' = 8000
        )
        OptionSpec.u64(
          "size",
          "The size percentage threshold. Defaults to 10."
          where short' = 's', default' = 10
        )
        OptionSpec.u64(
          "write",
          "The insert percentage threshold. Defaults to 1."
          where short' = 'p', default' = 1
        )
      ]) ?
    end

actor Concsll
  new run(args: Command val, env: Env) =>
    Master(
      args.option("workers").u64(),
      args.option("messages").u64(),
      args.option("size").u64(),
      args.option("write").u64(),
      env
    )

actor Master
  new create(workers: U64, messages: U64, size: U64, write: U64, env: Env) =>
    let list = SortedList

    for i in Range[U64](0, workers) do
      env.out.print("creating worker: " + i.string())
      Worker(messages, size, write, list, env).work()
    end

actor Worker
  let _random: Rand
  let _size: U64
  let _write: U64
  let _list: SortedList
  let _env: Env

  var _messages: U64

  new create(messages: U64, size: U64, write: U64, list: SortedList, env: Env) =>
    _random = Rand(messages + size + write)
    _size = size
    _write = write
    _list = list
    _env = env

    _messages = messages
 
  be work(value: U64 = 0) =>
    _messages = _messages - 1

    if _messages > 0 then
      let value' = _random.int(100)

      if value' < _size then
        _list.size(this)
      elseif value' < (_size + _write) then
        _list.write(this, value')
      else
        _list.contains(this, value')
      end
    end

actor SortedList
  let _data: SortedLinkedList[U64]

  new create() =>
    _data = SortedLinkedList[U64]

  be write(worker: Worker, value: U64) =>
    _data.push(value)
    worker.work(value)

  be contains(worker: Worker, value: U64) =>
    worker.work(if _data.contains(value) then 0 else 1 end)

  be size(worker: Worker) =>
    worker.work(_data.size().u64())


class SortedLinkedList[A: Comparable[A] #read]
  """
  A (simple) doubly linked sorted list.
  Helper data structure for this benchmark
  only. Not meant to be complete.
  """
  let _list: List[A] = List[A]

  fun ref push(a: A) =>
    if _list.size() == 0 then
      _list.push(a)
    else
      for n in _list.nodes() do
        try 
          if n() ? <= a then
            n.append(ListNode[A](a))
          end 
        end
      end
    end

  fun contains(a: box->A): Bool =>
    _list.contains(a)

  fun size(): USize =>
    _list.size()

use "collections"
use "../../util"

class iso Concsll is AsyncActorBenchmark
  let _workers: U64
  let _messages: U64
  let _size: U64
  let _write: U64

  new iso create(workers: U64, messages: U64, size: U64, write: U64) =>
    _workers = workers
    _messages = messages
    _size = size
    _write = write
  
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Master(
      c,
      _workers,
      _messages,
      _size,
      _write
    )
  
  fun tag name(): String => "Concurrent Sorted Linked-List"

actor Master
  let _bench: AsyncBenchmarkCompletion
  var _workers: U64

  new create(c: AsyncBenchmarkCompletion, workers: U64, messages: U64, size: U64, write: U64) =>
    _bench = c
    _workers = workers

    let list = SortedList

    for i in Range[U64](0, workers) do
      Worker(this, messages, size, write, list).work()
    end
  
  be done() =>
    if (_workers = _workers - 1) == 1 then
      _bench.complete()
    end

actor Worker
  let _master: Master
  let _size: U64
  let _write: U64
  let _list: SortedList
  let _random: SimpleRand

  var _messages: U64

  new create(master: Master, messages: U64, size: U64, write: U64, list: SortedList) =>
    _master = master
    _size = size
    _write = write
    _list = list
    _random = SimpleRand(messages + size + write)

    _messages = messages
 
  be work(value: U64 = 0) =>
    _messages = _messages - 1

    if _messages > 0 then
      let value' = _random.nextInt(where max = 100).u64()

      if value' < _size then
        _list.size(this)
      elseif value' < (_size + _write) then
        _list.write(this, value')
      else
        _list.contains(this, value')
      end
    else
      _master.done()
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
            return
          end 
        end
      end
    end

  fun contains(a: box->A): Bool =>
    _list.contains(a)

  fun size(): USize =>
    _list.size()

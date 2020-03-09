use "cli"
use "collections"
use "time"
use "random"
use "../../util"
use "math"
use "format"
use "term"

type ClientMap is Map[U64, Client]
type FriendSet is SetIs[Client]
type ChatSet is SetIs[Chat]
type ClientSet is SetIs[Client]

primitive Post
primitive Leave
primitive Invite
primitive Compute

type Action is
  ( Post
  | Leave
  | Invite 
  | Compute
  | None
  )

class val BehaviorFactory
  let _compute: U64
  let _post: U64
  let _leave: U64
  let _invite: U64

  new create(compute: U64, post: U64, leave: U64, invite: U64) =>
    _compute = compute
    _post = post
    _leave = leave
    _invite = invite

  fun box apply(dice: DiceRoll): (Action | None) =>
    var action: (Action | None) = None

    if dice(_compute) then
      action = Compute
    elseif dice(_post) then
      action = Post
    elseif dice(_leave) then
      action = Leave
    elseif dice(_invite) then
      action = Invite
    end
    
    action
    
actor Chat
  let _members: ClientSet
  var _buffer: Array[(Array[U8] val | None)]
  
  new create(initiator: Client) =>
    _members = ClientSet
    _buffer =  Array[(Array[U8] val | None)]

    _members.set(initiator)

  be post(payload: (Array[U8] val | None), done: {(): None} val) =>
    ifdef "_BENCH_NO_BUFFERED_CHATS" then
      None
    else
      _buffer.push(payload)
    end

    var token = object
      var _acknowledgements: USize = _members.size()

      be apply() =>
        if (_acknowledgements = _acknowledgements - 1) == 1 then
          done()
        end
    end

    for member in _members.values() do
      member.forward(this, payload, token)
    else
      done()
    end

  be acknowledge(acknowledgement: {tag (): None} tag) =>
    acknowledgement()

  be join(client: Client, acknowledgement: {tag(): None} tag) =>
    _members.set(client)
   
    ifdef "_BENCH_NO_BUFFERED_CHATS" then
       acknowledgement()
    else
      let replay = object
        var _completions: USize = _buffer.size()
        
        be apply() =>
          if (_completions = _completions - 1) == 1 then
            acknowledgement()
          end
      end

      var did_forward: Bool = false

      for message in _buffer.values() do
        client.forward(this, message, replay)
        did_forward = true
      end

      if not did_forward then
        acknowledgement()
      end  
    end
  
  be leave(client: Client, did_logout: Bool, done: {(): None} val) =>
    _members.unset(client)
    client.left(this, did_logout, done)

actor Client
  let _id: U64
  let _friends: FriendSet
  let _chats: ChatSet
  let _directory: Directory
  let _dice: DiceRoll
  let _rand: SimpleRand

  new create(id: U64, directory: Directory, seed: U64) =>
    _id = id
    _friends = FriendSet
    _chats = ChatSet
    _directory = directory  
    _dice = DiceRoll(seed)
    _rand = SimpleRand(seed)

  be befriend(client: Client) =>
    _friends.set(client)
  
  be logout() =>
    for chat in _chats.values() do
      chat.leave(this, true, recover val {(): None => None} end)
    else 
      _directory.left(_id)
    end

  be left(chat: Chat, did_logout: Bool, done: {(): None} val) =>
    _chats.unset(chat)
      
    if ( _chats.size() == 0 ) and did_logout then
      _directory.left(_id)
    else
      done()
    end

  be invite(chat: Chat, token: {tag (): None} tag) =>
    _chats.set(chat)
    chat.join(this, token)

  be online(id: U64) =>
    None //No-op

  be offline(id: U64) =>
    None //No-op

  be forward(chat: Chat, payload: (Array[U8] val | None), token: {tag (): None} tag) =>
    token()

  be act(behavior: BehaviorFactory, accumulator: Accumulator) =>
    let index = _rand.nextInt(_chats.size().u32()).usize()
    var i: USize = 0

    // Pony has no implicit conversion from Seq to Array.
    var chat = Chat(this)
    
    for c in _chats.values() do
      if i == index then
        break
      end

      i = i + 1 ; chat = c
    end

    let done = recover val {(): None => accumulator.stop() /*_directory.completed(accumulator)*/} end

    match behavior(_dice)
    | Post => chat.post(None, done)
    | Leave => chat.leave(this, false, done)
    | Compute => Fibonacci(35) ; accumulator.stop() //_directory.completed(accumulator) //Mandelbrot(chat)
    | Invite => 
      let created = Chat(this)

      // Again convert the set values to an array, in order
      // to be able to use shuffle from rand
      let f = Array[Client](_friends.size())

      for friend in _friends.values() do
        f.push(friend)
      end

      let s = Rand(_rand.next())
      s.shuffle[Client](f)

      f.unshift(this)

      var invitations: USize = s.next().usize() % _friends.size()

      if invitations == 0 then
        invitations = 1
      end

      // prepare the completion handler
      let token = object
        var acknowledgements: USize = invitations

         be apply() =>
           if( acknowledgements = acknowledgements - 1) == 1 then
             //_directory.completed(accumulator)
             accumulator.stop()
           end
      end

      for k in Range[USize](0, invitations) do
        //pick random index k??
        try f(k)?.invite(created, token) end
      end
    else
      //_directory.completed(accumulator)
      accumulator.stop()
    end

actor Directory
  let _clients: ClientMap
  let _random: SimpleRand
  //var _start_size: USize
  //var _completions: USize
  var _poker: (Poker | None)

  new create(seed: U64) =>
    _clients = ClientMap
    _random = SimpleRand(seed)
    //_start_size = 0
    //_completions = 0
    _poker = None

  //be prepare(poker: Poker/*, turns: U64*/) =>
    //_start_size = _clients.size()
    //_completions = turns.usize()//_start_size * turns.usize()
    //_poker = poker

  be login(id: U64) =>
    let new_client = Client(id, this, _random.next())

    _clients(id) = new_client
    
    for client in _clients.values() do
      if _random.nextInt(100) < 10 then
        client.befriend(new_client)
        new_client.befriend(client)
      end
    end

  be logout(id: U64) =>
    try
      _clients(id)?.logout()
    end

  be status(id: U64, requestor: Client) =>
    try
      _clients(id)?
      requestor.online(id)
    else
      requestor.offline(id)
    end

  be left(id: U64) =>
    try
      _clients.remove(id)?

      if _clients.size() == 0 then
        match _poker
        | let poker: Poker => poker.finished()
        end
      end
    end

  be poke(factory: BehaviorFactory, accumulator: Accumulator) =>
    for client in _clients.values() do
      client.act(factory, accumulator)
    end

  /*be completed(/*accumulator: Accumulator*/) =>
    //accumulator.stop()
  
    if ( _completions = _completions - 1 ) == 1 then
      match _poker
      | let poker: Poker => poker.confirm()
      end
    end*/

  be disconnect(poker: Poker) =>
    _poker = poker 

    for c in _clients.values() do
      c.logout()
    end

actor Accumulator
  let _poker: Poker
  var _start: F64
  var _end: F64
  var _duration: F64
  var _expected: USize
  var _did_stop: Bool

  new create(poker: Poker, expected: USize) =>
    _poker = poker
    _start = Time.millis().f64()
    _end = 0
    _duration = 0
    _expected = expected
    _did_stop = false

  be stop() =>
    if (_expected = _expected - 1) == 1 then
      _end = Time.millis().f64()
      _duration = _end - _start
      _did_stop = true

      _poker.confirm()
    end

   be print(poker: Poker, i: USize, j: USize) =>
     poker.collect(i, j, _duration)

actor Poker
  var _clients: U64
  var _logouts: USize
  var _confirmations: USize
  var _turns: U64
  var _directories: Array[Directory] val
  var _runtimes: Array[Array[Accumulator]]
  var _accumulations: USize
  var _finals: Array[Array[F64]]
  var _factory: BehaviorFactory
  var _bench: (AsyncBenchmarkCompletion | None)
  var _last: Bool
  var _turn_series: Array[F64]
  var _env: Env
  
  new create(clients: U64, turns: U64, directories: Array[Directory] val, factory: BehaviorFactory, env: Env) =>
    _clients = clients
    _logouts = 0
    _confirmations = 0
    _turns = turns
    _directories = directories
    _runtimes = Array[Array[Accumulator]]
    _accumulations = 0
    _finals = Array[Array[F64]]
    _factory = factory
    _bench = None
    _last = false
    _turn_series = Array[F64]
    _env = env

  be apply(bench: AsyncBenchmarkCompletion, last: Bool) =>
    _confirmations = _turns.usize()
    _logouts = _directories.size()
    _bench = bench
    _last = last

    var turns: U64 = _turns
    var index: USize = 0
    var values: Array[F64] = Array[F64].init(0, _turns.usize())

    _finals.push(values)

    for client in Range[U64](0, _clients) do
      try
        index = client.usize() % _directories.size()
        _directories(index)?.login(client)
      end
    end

    /*for directory in _directories.values() do
      directory.prepare(this, _turns)
    end*/

    let accumulators = Array[Accumulator]

    while ( turns = turns - 1 ) >= 1 do
      let accumulator = Accumulator(this, _clients.usize())

      for directory in _directories.values() do
        directory.poke(_factory, accumulator)
      end

      accumulators.push(accumulator)
    end

    _runtimes.push(accumulators)
    
  be confirm() =>
    if (_confirmations = _confirmations - 1 ) == 1 then
      for d in _directories.values() do
        d.disconnect(this)
      end
    end

  be finished() =>
    if (_logouts = _logouts - 1 ) == 1 then
      match _bench
      | let bench: AsyncBenchmarkCompletion => bench.complete()
      end
      
      if _last then
        var iteration: USize = 0
        var turn: USize = 0

        for accumulators in _runtimes.values() do
          for accumulator in accumulators.values() do
            accumulator.print(this, iteration, turn)
            turn = turn + 1
          end

          _accumulations = _accumulations + turn
          turn = 0

          iteration = iteration + 1
        end
      end      
    end

  be collect(i: USize, j: USize, duration: F64) =>
    try
      _finals(i)?(j)? = duration
      _turn_series.push(duration)
    end

    if ( _accumulations = _accumulations - 1 ) == 1 then
      let stats = SampleStats(_turn_series = Array[F64])
      var turns = Array[Array[F64]]
      var qos = Array[F64]

      for k in Range[USize](0, _turns.usize()) do
        try 
          turns(k)? 
        else 
          turns.push(Array[F64]) 
        end

        for iter in _finals.values() do 
          try turns(k)?.push(iter(k)?) end
        end
      end
      
      for l in Range[USize](0, turns.size()) do
        try qos.push(SampleStats(turns.pop()?).stddev()) end
      end

      _env.out.print(
        "".join(
          [ ANSI.bold()
            Format("" where width = 31)
            Format("j-mean" where width = 18, align = AlignRight)
            Format("j-median" where width = 18, align = AlignRight)
            Format("j-error" where width = 18, align = AlignRight)
            Format("j-stddev" where width = 18, align = AlignRight)
            Format("quality of service" where width = 32, align = AlignRight)
            ANSI.reset()
          ].values()
        )
      )

      _env.out.print(
        "".join([
            Format("Turns" where width = 31)
            Format(stats.mean().string() + " ms" where width = 18, align = AlignRight)
            Format(stats.median().string() + " ms" where width = 18, align = AlignRight)
            Format("±" + stats.err().string() + " %" where width = 18, align = AlignRight)
            Format(stats.stddev().string() where width = 18, align = AlignRight)
            Format(SampleStats(qos = Array[F64]).median().string() where width = 32, align = AlignRight)
          ].values()
        )
      )
    end

class iso ChatApp is AsyncActorBenchmark
  var _clients: U64
  var _turns: U64
  var _directories: Array[Directory] val
  var _factory: BehaviorFactory val
  var _poker: Poker

  new iso create(env: Env) =>
    _clients = 32768
    _turns = 20

    let directories: USize = USize(256)
    let compute: U64 = 50
    let post: U64 = 80
    let leave: U64 = 25
    let invite: U64 = 25
    let rand = SimpleRand(42)

    _factory = recover BehaviorFactory(compute, post, leave, invite) end

    _directories = recover
      let dirs = Array[Directory](directories)

      for i in Range[USize](0, directories.usize()) do
        dirs.push(Directory(rand.next()))
      end
        
      dirs
    end

    _poker = Poker(_clients, _turns, _directories, _factory, env)

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) => _poker(c, last)

  fun tag name(): String => "Chat App"

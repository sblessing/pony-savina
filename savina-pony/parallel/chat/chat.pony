use "cli"
use "collections"
use "time"
use "random"
use "../../util"
use "math"

type ClientMap is Map[U64, Client]
type FriendSet is SetIs[Client]
type ChatSet is SetIs[Chat]
type ClientSet is SetIs[Client]

primitive Arguments
  fun apply(spec: CommandSpec iso, env: Env): Command val ? =>
    recover
      match CommandParser(consume spec).parse(env.args, env.vars)
      | let command: Command box => command
      | let help: CommandHelp => help.print_help(env.out) ; env.exitcode(0) ; error
      | let syntax: SyntaxError => env.out.print(syntax.string()) ; env.exitcode(1) ; error
      end
    end

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
  let _members: ClientSet = ClientSet

  be post(payload: (Array[U8] val | None), done: {(): None} val) =>
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
    acknowledgement()

  
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
    end

  be left(chat: Chat, did_logout: Bool, done: {(): None} val) =>
    done() ; _chats.unset(chat)
      
    if ( _chats.size() == 0 ) and did_logout then
      _directory.left(_id)
    end

  be invite(chat: Chat, token: {tag (): None} tag) =>
    _chats.set(chat)
    chat.join(this, token)

  be online(id: U64) =>
    None //No-op

  be offline(id: U64) =>
    None //No-op

  be forward(chat: Chat, payload: (Array[U8] val | None), token: {tag (): None} tag) =>
    chat.acknowledge(token)

  be act(behavior: BehaviorFactory) =>
    let index = _rand.nextInt(_chats.size().u32()).usize()
    var i: USize = 0

    // Pony has no implicit conversion from Seq to Array.
    var chat = Chat
    
    for c in _chats.values() do
      if i == index then
        break
      end

      i = i + 1 ; chat = c
    end

    let done = recover val {(): None => _directory.completed()} end

    match behavior(_dice)
    | Post => chat.post(None, done)
    | Leave => chat.leave(this, false, done)
    | Compute => Fibonacci(35) ; _directory.completed() //Mandelbrot(chat)
    | Invite => 
      let created = Chat

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
             _directory.completed()
           end
      end

      for k in Range[USize](0, invitations) do
        //pick random index k??
        try f(k)?.invite(created, token) end
      end
    else
      _directory.completed()
    end

actor Directory
  let _clients: ClientMap
  let _random: SimpleRand
  var _completions: USize
  var _poker: (Poker | None)

  new create(seed: U64) =>
    _clients = ClientMap
    _random = SimpleRand(seed)
    _completions = 0
    _poker = None

  be set_poker(poker: Poker) =>
    _poker = poker

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

        _poker = None
      end
    end

  be broadcast(factory: BehaviorFactory) =>
    _completions = _completions + _clients.size()

    for client in _clients.values() do
      client.act(factory)
    end

  be completed() =>
    if (_completions = _completions - 1) == 1 then
      match _poker
      | let poker: Poker => poker.confirm()
      end
    end
   
actor Poker
  var _clients: U64
  var _logouts: USize
  var _confirmations: USize
  var _turns: U64
  var _directories: Array[Directory] val
  var _runtimes: Array[F64]
  var _factory: BehaviorFactory
  var _bench: AsyncBenchmarkCompletion
  
  new poke(clients: U64, turns: U64, directories: Array[Directory] val, factory: BehaviorFactory, bench: AsyncBenchmarkCompletion) =>
    _clients = clients
    _logouts = directories.size()
    _confirmations = directories.size() * turns.usize()
    _turns = turns
    _directories = directories
    _runtimes = Array[F64](_turns.usize())
    _factory = factory
    _bench = bench

    for directory in directories.values() do
      directory.set_poker(this)
    end

    for client in Range[U64](0, clients) do
      try
        let index = client.usize() % directories.size()
        directories(index)?.login(client)
      end
    end

    while ( _turns = _turns - 1 ) > 1 do
      _runtimes.push(Time.millis().f64())

      for directory in _directories.values() do
        directory.broadcast(_factory)
      end
    end
    
  be confirm() =>
    try 
      let index = _runtimes.size() - _confirmations
      let start = _runtimes(index) ?
      let finish = Time.millis().f64()

      _runtimes(index)? = finish - start
    end

    if (_confirmations = _confirmations - 1 ) == 1 then
      /**
       * The logout/teardown phase may only happen
       * after we know that all turns have been
       * carried out completely.
       */
      for client in Range[U64](0, _clients) do
        try
          let index = client.usize() % _directories.size()
          _directories(index)?.logout(client)
        end
      end
    end

  be finished() =>
    if (_logouts = _logouts - 1 ) == 1 then
       let qos = SampleStats(_runtimes = Array[F64])
      _bench.complete(qos.stddev())
    end

class iso ChatApp is AsyncActorBenchmark
  var _clients: U64
  var _turns: U64
  var _directories: Array[Directory] val
  var _factory: BehaviorFactory val

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

  fun box apply(c: AsyncBenchmarkCompletion) => 
    Poker.poke(_clients, _turns, _directories, _factory, c)

  fun tag name(): String => "Chat App"

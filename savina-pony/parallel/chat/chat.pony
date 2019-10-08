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

  fun box apply(): ListValues[Action, ListNode[Action]] =>
    let dice = DiceRoll(Time.millis())
    let actions = List[Action]

    if dice(_compute) then
      actions.push(Compute)
    elseif dice(_post) then
      actions.push(Post)
    elseif dice(_leave) then
        actions.push(Leave)
    elseif dice(_invite) then
        actions.push(Invite)
    end
    
    actions.values()
    
actor Chat
  let _members: ClientSet = ClientSet

  be post(payload: (Array[U8] val | None)) =>
    for member in _members.values() do
      member.forward(this, payload)
    end

  be acknowledge() =>
    None //No-op

  be join(client: Client) =>
    _members.set(client)
  
  be leave(client: Client, did_logout: Bool) =>
    _members.unset(client)
    client.left(this, did_logout)

actor Client
  let _id: U64
  let _friends: FriendSet
  let _chats: ChatSet
  let _directory: Directory

  new create(id: U64, directory: Directory) =>
    _id = id
    _friends = FriendSet
    _chats = ChatSet
    _directory = directory

  fun ref _invite(chat: Chat) =>
    _chats.set(chat)
    chat.join(this)

  be befriend(client: Client) =>
    _friends.set(client)
  
  be logout() =>
    for chat in _chats.values() do
      chat.leave(this, true)
    end

  be left(chat: Chat, did_logout: Bool) =>
    _chats.unset(chat)
      
    if ( _chats.size() == 0 ) and did_logout then
      _directory.left(_id)
    end

  be invite(chat: Chat) =>
    _invite(chat)

  be online(id: U64) =>
    None //No-op

  be offline(id: U64) =>
    None //No-op

  be forward(chat: Chat, payload: (Array[U8] val | None)) =>
    chat.acknowledge()

  be act(behavior: BehaviorFactory) =>
    let index = SimpleRand(42).next().usize() % _chats.size()
    var i: USize = 0

    // Pony has no implicit conversion from Seq to Array.
    var chat = Chat
    
    for c in _chats.values() do
      if i == index then
        break
      end

      i = i + 1 ; chat = c
    end

    for action in behavior() do
      match action
      | Post => chat.post(None)
      | Leave => chat.leave(this, false)
      | Compute => Fibonacci(35) //Mandelbrot(chat)
      | Invite => 
        let created = Chat
        _invite(created)

        // Again convert the set values to an array, in order
        // to be able to use shuffle from rand
        let f = Array[Client](_friends.size())

        for friend in _friends.values() do
          f.push(friend)
        end

        let s = Rand(42)
        s.shuffle[Client](f)

        for k in Range[USize](0, s.next().usize() % _friends.size()) do
          try f(k)?.invite(created) end
        end
      end
    end

actor Directory
  let _clients: ClientMap
  let _random: SimpleRand
  var _poker: (Poker | None)

  new create() =>
    _clients = ClientMap
    _random = SimpleRand(42)
    _poker = None

  be set_poker(poker: Poker) =>
    _poker = poker

  be login(id: U64) =>
    let new_client = Client(id, this)

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
        | let poker: Poker => poker.confirm()
        end

        _poker = None
      end
    end

  be broadcast(factory: BehaviorFactory) =>
    for client in _clients.values() do
      client.act(factory)
    end
   
actor Poker
  var _clients: U64
  var _confirmations: USize
  var _turns: U64
  var _directories: Array[Directory] val
  var _factory: BehaviorFactory
  var _bench: AsyncBenchmarkCompletion
  
  new poke(clients: U64, turns: U64, directories: Array[Directory] val, factory: BehaviorFactory, bench: AsyncBenchmarkCompletion) =>
    _clients = clients
    _confirmations = directories.size()
    _turns = turns
    _directories = directories
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
      for directory in _directories.values() do
        directory.broadcast(_factory)
      end
    end
    
    for client in Range[U64](0, _clients) do
      try
        let index = client.usize() % _directories.size()
        _directories(index)?.logout(client)
      end
    end
    
  be confirm() =>
    if (_confirmations = _confirmations - 1 ) == 1 then
      _bench.complete()
    end

class iso ChatApp is AsyncActorBenchmark
  var _clients: U64
  var _turns: U64
  var _directories: Array[Directory] val
  var _factory: BehaviorFactory val

  new iso create(env: Env) =>
    _clients = 256
    _turns = 20

    let directories: USize = USize(16)
    let compute: U64 = 50
    let post: U64 = 80
    let leave: U64 = 25
    let invite: U64 = 25

    _factory = recover BehaviorFactory(compute, post, leave, invite) end

    _directories = recover
      let dirs = Array[Directory](directories)

      for i in Range[USize](0, directories.usize()) do
        dirs.push(Directory)
      end
        
      dirs
    end

  fun box apply(c: AsyncBenchmarkCompletion) => 
    Poker.poke(_clients, _turns, _directories, _factory, c)

  fun tag name(): String => "Chat App"

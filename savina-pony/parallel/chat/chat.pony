use "cli"
use "collections"
use "time"
use "random"
use "../util"

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

type Action is
  ( Post
  | Leave
  | Invite 
  | None
  )

class val BehaviorFactory
  let _nothing: U64
  let _post: U64
  let _leave: U64
  let _invite: U64

  new create(nothing: U64, post: U64, leave: U64, invite: U64) =>
    _nothing = nothing
    _post = post
    _leave = leave
    _invite = invite

  fun box apply(): ListValues[Action, ListNode[Action]] =>
    let dice = DiceRoll(Time.millis())
    let actions = List[Action]

    if dice(_nothing) then
      actions.push(None)
    else
      if dice(_post) then
       actions.push(Post)
      else 
        if dice(_leave) then
          actions.push(Leave)
        end

        if dice(_invite) then
          actions.push(Invite)
        end
      end
    end
    
    actions.values()
    
actor Chat
  let _members: ClientSet = ClientSet

  be post() =>
    for member in _members.values() do
      member.forward(this)
    end

  be acknowledge() =>
    None //No-op

  be join(client: Client) =>
    _members.set(client)
  
  be leave(client: Client) =>
    _members.unset(client)

actor Client
  let _id: U64
  let _friends: FriendSet
  let _chats: ChatSet

  new create(id: U64) =>
    _id = id
    _friends = FriendSet
    _chats = ChatSet

  fun ref _invite(chat: Chat) =>
    _chats.set(chat)
    chat.join(this)

  be befriend(client: Client) =>
    _friends.set(client)
  
  be logout(driver: BenchmarkDriver) =>
    for chat in _chats.values() do
      chat.leave(this)
    end

    _chats.clear()

    driver.confirm()
  
  be invite(chat: Chat) =>
    _invite(chat)

  be online(id: U64) =>
    None //No-op

  be offline(id: U64) =>
    None //No-op

  be forward(chat: Chat) =>
    chat.acknowledge()

  be act(behavior: BehaviorFactory) =>
    let index = SimpleRand(Time.millis()).next().usize() % _chats.size()
    var i: USize = 0

    // Pony has no implicit conversion from Seq toArray.
    var chat = Chat
    
    for c in _chats.values() do
      if i == index then
        break
      end

      i = i + 1 ; chat = c
    end

    for action in behavior() do
      match action
      | Post => chat.post()
      | Leave => chat.leave(this) ; _chats.unset(chat)
      | Invite => 
        let created = Chat
        _invite(created)

        // Again convert the set values to an array, in order
        // to be able to use shuffle from rand
        let f = Array[Client](_friends.size())

        for friend in _friends.values() do
          f.push(friend)
        end

        let s = Rand(Time.millis())
        s.shuffle[Client](f)

        for k in Range[USize](0, s.next().usize() % _friends.size()) do
          try f(k)?.invite(created) end
        end
      end
    end

actor Directory
  let _clients: ClientMap = ClientMap
  let _random: SimpleRand = SimpleRand(42)

  be login(id: U64) =>
    let new_client = Client(id)

    _clients(id) = new_client
    
    for client in _clients.values() do
      if _random.nextInt(100) < 10 then
        client.befriend(new_client)
        new_client.befriend(client)
      end
    end
  
  be logout(id: U64, driver: BenchmarkDriver) =>
    try
      (_, let client) = _clients.remove(id)?
      client.logout(driver)
    end

  be status(id: U64, requestor: Client) =>
    try
      _clients(id)?
      requestor.online(id)
    else
      requestor.offline(id)
    end 

  be next(id: U64, behavior: BehaviorFactory) =>
    try
      _clients(id)?.act(behavior)   
    end

actor BenchmarkDriver
  let _bench: AsyncBenchmarkCompletion
  let _factory: BehaviorFactory
  let _directories: Array[Directory] val
  var _clients: U64

  new create(bench: AsyncBenchmarkCompletion, factory: BehaviorFactory, directories: Array[Directory] val, turns: U64, clients: U64) =>
    _bench = bench
    _factory = factory
    _directories = directories
    _clients = clients

    for i in Range[U64](0, clients) do
      _login(i)
    end

    for j in Range[U64](0, turns) do
      for k in Range[U64](0, clients) do
        _poke(k)
      end 
    end

    for l in Range[U64](0, clients) do
      _logout(l)
    end

  fun box _get_directory_for(id: U64): Directory? =>
    _directories(id.usize() % _directories.size())?

  fun box _login(id: U64) =>
    try
      _get_directory_for(id)?.login(id)
    end
  
  fun box _logout(id: U64) =>
    try
      _get_directory_for(id)?.logout(id, this)
    end

  fun box _poke(id: U64) =>
    try
      match _factory
      | let factory: BehaviorFactory => _get_directory_for(id)?.next(id, factory)
      end
    end   

  be confirm() =>
    if (_clients = _clients - 1) == 1 then
      _bench.complete()
    end

class iso ChatApp is AsyncActorBenchmark
  var _clients: U64
  var _turns: U64
  var _directories: (Array[Directory] val | None)
  var _factory: (BehaviorFactory val | None)

  new iso create(env: Env) =>
    _directories = None
    _factory = None
    _clients = 0
    _turns = 0
    _init(env)

  fun ref _init(env: Env) =>
    try
      let spec = 
        recover iso
          CommandSpec.leaf("lola",
            """
            A tuneable actor benchmark.
            """, 
            [
              OptionSpec.u64(
                "clients",
                "The number of clients. Defaults to 2048"
                where short' = 'c', default' = 2048
              )
              OptionSpec.u64(
                "directories",
                "The number of directory actors. Defaults to 16."
                where short' = 'd', default' = 16
              )
              OptionSpec.u64(
                "turns",
                "The number of turns execute. Defaults to 20."
                where short' = 't', default' = 20
              )
              OptionSpec.u64(
                "nothing",
                "The probability for a client to do nothing. Defaults to 50%."
                where short' = 'n', default' = 50
              )
              OptionSpec.u64(
                "post",
                "The probability for a client to post something. Defaults to 80%."
                where short' = 'p', default' = 80
              )
              OptionSpec.u64(
                "leave",
                "The probability for a client to leave a chat. Defaults to 25%."
                where short' = 'l', default' = 25
              )
              OptionSpec.u64(
                "invite",
                "The probability for client to create a new chat and invite a subset of its friends. Defaults to 25%."
                where short' = 'i', default' = 25
              )
            ]
          )?
        end

      let command = Arguments(consume spec, env) ?

      _clients = command.option("clients").u64()
      _turns = command.option("turns").u64()

      let directories: USize = command.option("directories").u64().usize()
      let nothing: U64 = command.option("nothing").u64()
      let post: U64 = command.option("post").u64()
      let leave: U64 = command.option("leave").u64()
      let invite: U64 = command.option("invite").u64()

      _factory = recover BehaviorFactory(nothing, post, leave, invite) end

      _directories = recover
        let dirs = Array[Directory](directories)

        for i in Range[USize](0, directories.usize()) do
          dirs.push(Directory)
        end
        
        dirs
      end
    end

  fun box apply(c: AsyncBenchmarkCompletion) => 
    match (_factory, _directories)
    | (let f: BehaviorFactory, let d: Array[Directory] val) => BenchmarkDriver(c, f, d, _turns, _clients)
    end    

  fun tag name(): String => "Chat App"
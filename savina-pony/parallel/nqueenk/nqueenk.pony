use "cli"
use "collections"

primitive NqueenkConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("nqueenk", "", [
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 20."
          where short' = 'w', default' = 20
        )
        OptionSpec.u64(
          "size",
          "The overall size. Defaults to 12."
          where short' = 's', default' = 12
        )
        OptionSpec.u64(
          "threshold",
          "The threshold. Defaults to 4."
          where short' = 't', default' = 4
        )
        OptionSpec.u64(
          "priorities",
          "The priority levels. Defaults to 10. Maximum value is 29."
          where short' = 'p', default' = 10
        )
        OptionSpec.u64(
          "solutions",
          "The solutions limit. Defaults to 1500000."
          where short' = 'r', default' = 1500000
        )
      ]) ?
    end

primitive BoardValidator
  fun valid(i: U64, j: U64, p: U64, q: U64): Bool =>
    let r = p - (j - i)
		let s = p + (j - i)

		if (q == p) or (q == r) or (q == s) then
		  return false
	  end

    true

  fun apply(data: Array[U64] iso, depth: U64): (Array [U64] iso^ | None) =>
	  for i in Range[U64](0, depth) do
      try
        let p: U64 = data(i.usize())?

        for j in Range[U64](i + 1, depth) do
				  try
            let q: U64 = data(j.usize()) ?
						if not valid(i, j, p, q) then
						  return None
						end 
					end					
        end
      end
    end

    consume data

	fun validate(data: Array[U64] ref, depth: U64): Bool =>
	  for i in Range[U64](0, depth) do
      try
        let p: U64 = data(i.usize())?

        for j in Range[U64](i + 1, depth) do
				  try
            let q: U64 = data(j.usize()) ?
						if not valid(i, j, p, q) then
						  return false
						end 
					end					
        end
      end
    end

		true

actor Nqueenk
  new run(args: Command val, env: Env) =>
    let workers = args.option("workers").u64()
    let priorities = U64(1).max(args.option("priorities").u64().min(29))
    let limit = args.option("solutions").u64()
    let threshold = U64(1).max(args.option("threshold").u64().min(Solutions.max()))
    let size = U64(1).max(args.option("size").u64().min(Solutions.max()))
    
    Master(this, workers, priorities, limit, threshold, size, env)

actor Master
  let _runner: Nqueenk
  let _priorities: U64
  let _limit: U64
	let _env: Env
	
  var _workers: Array[Worker]
  var _signalled: U64
  var _messages_sent: U64
  var _results: U64
  
  new create(runner: Nqueenk, workers: U64, priorities: U64, limit: U64, threshold: U64, size: U64, env: Env) =>
    _runner = runner
    _priorities = priorities
    _limit = limit
		_env = env
		_workers = Array[Worker](workers.usize())

    _signalled = 0
    _messages_sent = 0 
    _results = 0

    for i in Range[U64](0, workers) do
      _workers.push(Worker(this, threshold, size, env))
    end

    _send_work(priorities, recover Array[U64](0) end)

  fun ref _send_work(priorities: U64, data: Array[U64] val, depth: U64 = 0) =>
    try 
      let priority = U64(priorities - 1).min(U64(0).max(priorities))

      _workers(_messages_sent.usize())?.work(priority, depth, data) 
      _messages_sent = ( _messages_sent + 1 ) % _workers.size().u64()
      _signalled = _signalled + 1
    end

  be work(priority: U64, data: Array[U64] val, depth: U64) =>
	  if _results < _limit then
      _send_work(priority, data, depth)
		else
		  _env.out.print(_results.string())    
		end

  be result() =>
    _results = _results + 1

actor Worker
  let _master: Master
  let _threshold: U64
  let _size: U64
	let _env: Env

  new create(master: Master, threshold: U64, size: U64, env: Env) =>
    _master = master
    _threshold = threshold
    _size = size
		_env = env

	fun ref rec_kernel(data: Array[U64] ref, depth: U64, new_depth: U64) =>
	    if _size == depth then
			  _master.result()
		  else
				for i in Range[U64](0, _size) do 
					try data(depth.usize()) ? = i end

           if BoardValidator.validate(data, depth) then
					   rec_kernel(data, new_depth, new_depth + 1)
					 end					
				end
			end

  fun ref par_kernel(priority: U64, depth: U64, data: Array[U64] val) =>
	  let new_priority = priority - 1
    let new_depth = depth + 1
    
		if _size == depth then
      _master.result()
    elseif depth >= _threshold then
		  var new_data = Array[U64].init(U64(0), new_depth.usize())
		  new_data.append(data, 0, depth.usize())
			rec_kernel(new_data, depth, new_depth)
	  else 
      for i in Range[U64](0, _size) do
        var new_data = recover Array[U64].init(U64(0), new_depth.usize()) end
		    new_data.append(data, 0, depth.usize())

        try new_data(depth.usize()) ? = i end
        
        match BoardValidator(consume new_data, new_depth)
	     	| let valid: Array[U64] iso => _master.work(new_priority, consume valid, new_depth)
        end
      end
		end

  be work(priority: U64, depth: U64, data: Array[U64] val) =>
	  par_kernel(priority, depth, data)
# Pokemon Battle Simulator

import httpClient, json, random, colorize, strutils

# This JSON takes a while to load...annoying
let effectiveness = json.parseFile("data/effectiveness.json")

# Types
type
  Pokemon = ref object
    id: int
    name: string
    level: int
    xp: int
    status: string
    weight: int
    height: int
    types: seq[string]
    moves: seq[Move]
    stats: Stats

  Move = ref object
    name: string
    url: string
    category: string
    moveType: string
    pp: int
    accuracy: int
    power: float
    priority: int
    effectChance: int
    effects: seq[string]
    statChanges: seq[string]
    

  Stats = ref object
    hp: int
    attack: int
    defense: int
    speed: int

  Trainer = ref object
    name: string
    pokemon: seq[Pokemon]

  Battle = ref object
    client: HttpClient
    api: string
    player: Trainer
    opponent: Trainer


# Procedures

# Check if string is int
proc isInt*(s: string): bool =
  try:
    discard s.parseInt()
    result = true
  except:
    discard

# Loads pokemon data from the pokeapi
proc getPokemon(battle: Battle, id: int): Pokemon =
    var reqUrl = battle.api & $id
    var req = battle.client.getContent(reqUrl)
    let jsonNode = parseJson(req)
    var p = Pokemon(
        id: id,
        name: jsonNode["name"].getStr(),
        level: 20,
        xp: jsonNode["base_experience"].getInt(),
        status: "None",
        weight: jsonNode["weight"].getInt(),
        height: jsonNode["height"].getInt(),
        types: newSeq[string](),
        moves: newSeq[Move](),
        stats: Stats()
    )

    # Parse Pokemon types
    for pType in jsonNode["types"]:
        var t = pType["type"]["name"].getStr().toUpperAscii()
        p.types.add(t)

    # Parse Pokemon stats
    for pStat in jsonNode["stats"]:
        var statName = pStat["stat"]["name"].getStr()
        case statName
        of "hp":
            p.stats.hp = pStat["base_stat"].getInt()
        of "attack":
            p.stats.attack = pStat["base_stat"].getInt()
        of "defense":
            p.stats.defense = pStat["base_stat"].getInt()
        of "speed":
            p.stats.speed = pStat["base_stat"].getInt()

    # Parse Pokemon moves
    var idx: int = 0
    for pMove in jsonNode["moves"]: # For now only get the first 4 learned moves
        if pMove["version_group_details"][0]["level_learned_at"].getInt() <= p.level and
           pMove["version_group_details"][0]["move_learn_method"]["name"].getStr() == "level-up" and
           idx < 4:
            idx.inc()
            var move = Move(
                name: pMove["move"]["name"].getStr(),
                url: pMove["move"]["url"].getStr()
            )
            var req = battle.client.getContent(move.url)
            let moveJson = parseJson(req)
            
            # Update move with api data
            move.accuracy = moveJson["accuracy"].getInt()
            move.moveType = moveJson["damage_class"]["name"].getStr()
            move.category = moveJson["type"]["name"].getStr().toUpperAscii()
            move.pp = moveJson["pp"].getInt()
            move.priority = moveJson["priority"].getInt()

            p.moves.add(move)

    result = p

# Creates a new battle
proc newBattle (): Battle =
    new result

    # Setup battle
    result.client = newHttpClient()
    result.api = "https://pokeapi.co/api/v2/pokemon/"

    # Create trainers
    result.player = Trainer(name: "Trainer A")
    result.opponent = Trainer(name: "Trainer B")

    # Generate pokemon
    randomize()
    var count = 3
    for i in countdown(count - 1, 0):
        var pA = result.getPokemon(rand(151))
        var pB = result.getPokemon(rand(151))
        result.player.pokemon.add(pA)
        result.opponent.pokemon.add(pB)

# Create new battle
var battle = newBattle()

# Calculate the type effectiveness for a move
proc calcTypeEffect(move: Move, target: Pokemon): float =
    if target.types.len == 2:
        # If the target pokemon has two category types
        var key1 = move.category & "+" & target.types[0] & "/" & target.types[1]
        if effectiveness.hasKey(key1):
            result = effectiveness[key1].getFloat()
        var key2 = move.category & "+" & target.types[0] & "/" & target.types[1]
        if effectiveness.hasKey(key2):
            result = effectiveness[key2].getFloat()
    elif target.types.len == 1:
        # If the target pokemon has one category type
        echo "Target has one type"
        var key1 = move.category & "+" & target.types[0]
        if effectiveness.hasKey(key1):
            result = effectiveness[key1].getFloat()
    else:
        # No type? Something went wrong
        echo "Invalid type calculation"
        result = 0

# Calculate a physical move damage

proc calcDamage (source: Pokemon, target: Pokemon, move: Move): float =
    randomize()

    # Source attack / target defense
    var ad = source.stats.attack / target.stats.defense
    # Base pokemon damage
    var base = (((((2 * source.level) / 5) + 2) * move.power * ad) / 50) + 2
    
    # Multiplier values
    var 
        targets = 1.0
        weather = 1.0
        critical = 1.0
        random = rand(0.85..1.0)
        stab = 1.0
        typeEffect = calcTypeEffect(move, target)
        burn = 1.0
        other = 1.0

    # Modifier (Sum of multipliers)
    var modifier = targets * weather * critical * random * stab * typeEffect * burn * other
    result = base * modifier


# Action: Fight
proc actionFight (pokemon: Pokemon): int =
    echo "    FIGHT    ".bold.fgRed.bgWhite
    echo "Enter action: ".bold.fgWhite

    let moves = pokemon.moves
    var idx: int = 0
    for move in moves:
        idx.inc()
        echo "(" & $idx & ") ".bold.fgWhite & (move.name).bold.fgLightGray
    echo "(" & $(idx + 1) & ") ".bold.fgWhite & "⬅ BACK".bold.fgDarkGray
    var choice = readLine(stdin)
    if (isInt(choice)):
        
        var c = choice.parseInt()
        echo "choice:" & $c & "/" & $idx
        if (c > 0 and c <= idx):
          result = c
        elif (c == idx + 1):
          result = 0
        else:
          echo "Invalid choice."
          result = actionFight(pokemon)
    else:
        echo "Invalid choice."
        result = actionFight(pokemon)

# Action prompt
proc chooseAction() =
    echo "Enter action: ".bold.fgWhite & "\n" &
         "(1) FIGHT".bold.fgLightRed & "\n" &
         "(2) PKMN".bold.fgLightYellow & "\n" &
         "(3) PACK".bold.fgLightBlue & "\n" &
         "(4) RUN".bold.fgLightGreen
    var choice = readLine(stdin)
    
    if (isInt(choice)):
        var c = choice.parseInt()
        case c
        of 1:
            var a = actionFight(battle.player.pokemon[0])
            if (a == 0): # Back was selected
                chooseAction()
            else: # Move was selected
                var selectedMove = battle.player.pokemon[0].moves[a - 1] # Fix move selection index
                if (selectedMove.moveType == "physical"): # If the move deals physical damage
                    var dmg = calcDamage(battle.player.pokemon[0], battle.opponent.pokemon[0], selectedMove)
                    echo "Damage: " & $dmg
                else: # If the move affects status
                    echo "Move: " & $selectedMove.name & " : " & selectedMove.moveType
        of 2:
            echo "PKMN"
        of 3:
            echo "Backpack not implemented yet"
            chooseAction()
        of 4:
            echo "Cannot run from battle"
            chooseAction()
        else:
          echo "Invalid choice."
          chooseAction()
    else:
        echo "Invalid choice."
        chooseAction()


# Initial battle messages
proc startBattle (battle: Battle) =
    echo ($battle.opponent.name).bold.fgRed & " wants to battle!".fgWhite
    var breakA = readLine(stdin)
    echo ($battle.opponent.name).bold.fgRed &
         " sent out ".fgWhite &
         ($battle.opponent.pokemon[0].name).bold.fgWhite &
         "!".fgWhite
    var breakB = readLine(stdin)
    echo "Go! ".fgWhite &
         ($battle.player.pokemon[0].name).bold.fgWhite &
         "!".fgWhite
    var breakC = readLine(stdin)
    chooseAction()

# Start the battle!
battle.startBattle()
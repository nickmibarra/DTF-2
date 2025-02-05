# Defend the Flag - Game Design Document
*"Your Strategy. Your Flag. Your Last Stand."*

## Table of Contents
- [Core Game Modes](#core-game-modes)
- [Key Features](#key-features)
- [Systems Design](#systems-design)
- [Progression Systems](#progression-systems)
- [Roadmap](#roadmap)
- [Game Loop](#game-loop)

## Core Game Modes

### Last Stand (Endless Mode)
- **Gold Economy:** Earn gold only from defeating enemies
- **Research Base:** Optional building for advanced upgrades
- **Enemy Scaling:** Exponential wave growth with sublinear gold rewards

### Campaign Mode
- **Progression:** Unlock new content through level completion
- **Optional Objectives:** Bonus gold for special challenges
  - "No walls built"
  - "Kill 50 enemies with traps"
  - "Complete level with 3 or fewer towers"

### Survival Scenarios (Post-launch)
- Pre-built maps with unique constraints
- Special rule sets (e.g., "No research", "50% gold reduction")

## Key Features

### Economy & Research
- **Gold-Only Resource System**
  - Earned through enemy kills
  - Used for:
    - Tower construction and upgrades
    - Wall fortification
    - Flag perks
    - Research Base construction
- **Research Base**
  - High initial investment
  - Unlocks advanced upgrades
  - Vulnerable to enemy priority targeting
  - Three specialization paths:
    - Offense
    - Defense
    - Utility

### Tower Systems

#### Base Tower Types
- **Ballista**
  - Cost-effective
  - Single-target piercing damage
  - High accuracy
- **Flamethrower**
  - Area of effect damage
  - Weak vs armored units
  - Damage over time
- **Arcane Tower**
  - Crowd control focus
  - Enemy slowdown
  - Premium cost

#### Veteran Tower System
- **Experience Through Kills**
  - Towers track individual kill counts
  - Permanent progression per tower instance
- **Rank Thresholds**
  - Rank 1: Default
  - Rank 2: 10 kills (+5% damage)
  - Rank 3: 25 kills (+7% damage)
  - Rank 4: 50 kills (+10% damage)
  - Rank 5: 100 kills (+15% damage)
- **Integration with Other Systems**
  - Veteran bonuses stack multiplicatively with research upgrades
  - Visual indicators show tower rank (e.g., glowing aura)
  - Optional: Ability to transfer veteran status to upgraded towers
  - Specialized perks at higher ranks:
    - Rank 3: Unlock unique ability
    - Rank 4: Reduced cooldowns
    - Rank 5: Special targeting options

### Wall System
- **Progression Tiers**
  - Wooden Walls (Basic)
  - Stone Walls (Fireproof)
  - Spiked Walls (Damage Reflection)
  - Energy Barriers (Research Required)

### Flag Perks
- **Active Buffs**
  - Battle Standard: Temporary fire rate boost
  - Scavenger's Bounty: Gold drop increase
  - Last Resort: Emergency damage boost
- **Cost Structure**
  - One-time purchases
  - Per-wave activation costs
  - Permanent until flag damage

## Enemy Design

### Adaptive Spawn System
- Enemies evolve based on player strategy
- Elite units with bonus rewards
- Dynamic difficulty scaling

### Enemy Factions
- **The Corrupted**
  - Self-healing near undefended flag
  - Corruption spread mechanics
- **Scavengers**
  - Gold theft mechanics
  - Resource denial focus

## Progression Systems

### Meta Progression
- **Honor Tokens**
  - Earned through high scores
  - Campaign achievements
  - Daily challenges
- **Unlockables**
  - Starting perks
  - Cosmetic rewards
  - Quality of life improvements

### Research Progression
- **Tech Tree Structure**
  - Three main branches
  - Cross-branch synergies
  - Respec options
- **Integration with Veteran System**
  - Research can unlock new veteran abilities
  - Special research options for veteran towers
  - Veteran-specific upgrade paths

## Roadmap

### Launch Version (1.0)
- Core tower/wall building
- Gold economy
- Research Base
- 15 campaign levels
- Last Stand mode with leaderboards

### Post-Launch (Year 1)
- **Hero Units DLC**
  - Player-controlled champions
  - Unique abilities
- **Sally Forth Mechanic**
  - AI ally spawning
  - Counter-attack systems
- **Dynamic Events**
  - Mid-wave challenges
  - Special rewards

## Game Loop Example

### Early Game (Waves 1-5)
1. Build basic defenses
2. Establish gold income
3. Plan upgrade path

### Mid Game (Waves 6-10)
1. Research Base construction
2. Specialized tower placement
3. Veteran tower development

### Late Game (Waves 11+)
1. Advanced research
2. Elite enemy management
3. Resource optimization

## Design Philosophy
- Simple to learn, hard to master
- Meaningful strategic choices
- Risk vs reward balance
- Endless replayability
- Progressive complexity 
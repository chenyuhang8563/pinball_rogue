extends Node

## Global gameplay signal bus.
##
## Systems that should not directly reference each other can communicate here.

signal marble_fell(marble: RigidBody2D)

## Emitted when an enemy is killed and combat-drop buffs may be awarded.
signal enemy_killed(enemy: Node2D)

## Emitted when a wave completes and wave reward buffs may be awarded.
signal wave_completed(wave: int)

## Emitted for marble-chain physical interactions that can drive chain buffs.
signal chain_collision(collider: Node, collision_type: String)

## Emitted by the run flow when a node option has resolved.
signal run_node_completed(node_kind: String)

## Emitted when the run flow starts a battle group.
signal battle_started(group_id: String)

## Emitted when all enemies in the active battle group are gone.
signal battle_completed(group_id: String)

## Emitted when the fixed v1 boss node has been cleared.
signal run_completed

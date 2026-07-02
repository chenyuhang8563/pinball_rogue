extends Node

## Global gameplay signal bus.
##
## Systems that should not directly reference each other can communicate here.

signal marble_fell(marble: RigidBody2D)
signal dash_skill_activated

## Emitted when an enemy is killed and combat-drop buffs may be awarded.
signal enemy_killed(enemy: Node2D)

## Emitted when a wave completes and wave reward buffs may be awarded.
signal wave_completed(wave: int)

## Emitted for marble-chain physical interactions that can drive chain buffs.
signal chain_collision(collider: Node, collision_type: String)

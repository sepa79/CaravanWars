class_name LocalGameBootstrap
extends RefCounted

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")

const PLAYER_PARTY_ID: String = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID


static func create_local_server() -> RefCounted:
    return GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()

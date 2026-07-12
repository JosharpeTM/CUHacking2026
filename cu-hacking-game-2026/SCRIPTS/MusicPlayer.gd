extends AudioStreamPlayer

## ---------------------------------------------------------
## BACKGROUND MUSIC — autoload singleton "Music"
## Registered as an autoload (see project.godot), so this node
## lives outside the current scene and survives scene changes:
## the track keeps playing seamlessly across menu -> race ->
## results, etc. boopbot.mp3 is imported with looping on, so it
## just runs forever once started.
##
## From anywhere you can call:
##   Music.set_music_volume(-6.0)   # adjust loudness (dB)
##   Music.stop_music()             # silence it
##   Music.play_music()             # (re)start it
## ---------------------------------------------------------

const TRACK: AudioStream = preload("res://AUDIO/boopbot.mp3")

@export var music_volume_db: float = 7.0  # default background level; music sits under SFX


func _ready() -> void:
	# Keep the music running even if the SceneTree is paused (e.g. a pause menu),
	# since an autoload otherwise inherits the paused state and would cut out.
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = TRACK
	bus = "Master"
	volume_db = music_volume_db
	if not playing:
		play()


func play_music() -> void:
	if not playing:
		play()


func stop_music() -> void:
	stop()


func set_music_volume(db: float) -> void:
	music_volume_db = db
	volume_db = db

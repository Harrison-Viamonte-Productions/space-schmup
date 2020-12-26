extends Node2D

func _ready():
	$CPUParticles2D.emitting = true;
	$CPUParticles2D.one_shot = true;
	$Tween.interpolate_callback(self, 0.75, "queue_free");
	$Tween.start();

extends Node

func _ready():
# Test 1: Direct dictionary access
var dict = {}
var keys = PackedStringArray()
keys.resize(100)
for i in 100:
 10000:
 100:
t("GDScript dict access: ", elapsed1, " us")

# Test 2: Array access overhead
var arr = []
arr.resize(100)
for i in 100:
 10000:
 100:
t("GDScript array access: ", elapsed2, " us")

get_tree().quit()

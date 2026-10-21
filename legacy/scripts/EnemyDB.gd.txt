extends RefCounted
class_name EnemyDB
## Single source of truth for every contact type.
##
## Adding a new threat is one entry in TYPES. Nothing else in the project
## hard-codes an enemy name. If you want a new airframe silhouette, add a
## builder to MeshFactory.build() and point "mesh" at it.
##
## Fields
##   display      : label shown on the HUD when the contact is tracked
##   mesh         : key passed to MeshFactory.build()
##   scale        : uniform scale applied to the built model
##   hp           : hit points (a 20mm round does ~10 by default)
##   radius       : hit sphere radius in metres (bullet collision)
##   speed        : cruise speed in m/s
##   alt          : [min, max] spawn altitude in metres
##   dist         : [min, max] spawn range in metres
##   behavior     : "beeline" | "strafe" | "terminal" | "hover" | "capital" |
##                  "weave" | "station" (close to a standoff ring, then orbit)
##   agility      : how hard it manoeuvres (0 = rails, 1 = twitchy)
##   threat       : hull damage if it reaches the ship
##   score        : points for a kill
##   cost         : wave-budget cost used by the wave director
##   min_wave     : earliest wave this type may be drawn
##   weak_points  : optional [{pos: Vector3 (local), radius: float, mult: float}]
##   carrier      : optional {type: String, count: int, interval: float}
##                  launches smaller craft while alive
##   boss         : optional bool. Gets the HUD integrity bar, an arrival
##                  banner, staged fires and a multi-blast death.
##   hit_volumes  : optional [{pos: Vector3 (model space), radius: float}]
##                  The real hitbox for big ships. `radius` then becomes only
##                  a broad-phase bound, so rounds through empty sky beside a
##                  360 m hull miss instead of hitting a giant sphere.
##   standoff     : optional [min, max] metres, used by "station" behaviour
##   carrier      : can also take {burst: int, types: [ids], bays: [Vector3],
##                  first: float} to release several craft at once from
##                  model-space bay points.
##   flares       : optional {count: int, interval: float, chance: float}
##                  countermeasures against your missiles. No type declares
##                  these yet - the machinery is live in Enemy.try_decoy(), so
##                  adding the field to any entry turns flares on for it.
##   warp         : optional {distance: float, unknown: String}. The contact
##                  shows up as a growing point of heat for a few seconds, then
##                  drops out of warp `distance` metres away and brakes hard
##                  into position. It can't be hit until it has stopped.
##   wreck        : optional bool. On death it breaks up and falls into the
##                  sea over several seconds instead of vanishing.
##   fire_scale   : optional size multiplier for damage fires on big hulls.

const TYPES := {
	"drone": {
		"display": "UAV / SMALL",
		"mesh": "drone", "scale": 1.0,
		"hp": 22.0, "radius": 3.2, "speed": 85.0,
		"alt": [80.0, 260.0], "dist": [900.0, 1400.0],
		"behavior": "weave", "agility": 0.45,
		"threat": 6.0, "score": 100, "cost": 1.0, "min_wave": 1,
	},
	"jet": {
		"display": "FAST JET",
		"mesh": "jet", "scale": 1.0,
		"hp": 55.0, "radius": 5.5, "speed": 240.0,
		"alt": [120.0, 480.0], "dist": [1500.0, 2100.0],
		"behavior": "strafe", "agility": 0.7,
		"threat": 14.0, "score": 250, "cost": 2.0, "min_wave": 2,
	},
	"helo": {
		"display": "ROTARY WING",
		"mesh": "helo", "scale": 1.0,
		"hp": 70.0, "radius": 5.0, "speed": 62.0,
		"alt": [45.0, 180.0], "dist": [800.0, 1300.0],
		"behavior": "hover", "agility": 0.35,
		"threat": 12.0, "score": 220, "cost": 2.0, "min_wave": 3,
	},
	"missile": {
		"display": "SEA-SKIMMER",
		"mesh": "missile", "scale": 1.0,
		"hp": 14.0, "radius": 2.4, "speed": 310.0,
		"alt": [12.0, 30.0], "dist": [1600.0, 2200.0],
		"behavior": "terminal", "agility": 0.25,
		"threat": 26.0, "score": 400, "cost": 2.5, "min_wave": 3,
	},
	"heavy_jet": {
		"display": "HEAVY / MULTI-ENGINE",
		"mesh": "heavy_jet", "scale": 1.0,
		"hp": 260.0, "radius": 13.0, "speed": 130.0,
		"alt": [300.0, 700.0], "dist": [1800.0, 2400.0],
		"behavior": "beeline", "agility": 0.15,
		"threat": 22.0, "score": 600, "cost": 4.0, "min_wave": 5,
		"weak_points": [
			{"pos": Vector3(-12.5, -2.0, 0.0), "radius": 3.0, "mult": 3.0},
			{"pos": Vector3(12.5, -2.0, 0.0), "radius": 3.0, "mult": 3.0},
			{"pos": Vector3(-6.0, -2.0, 0.0), "radius": 3.0, "mult": 3.0},
			{"pos": Vector3(6.0, -2.0, 0.0), "radius": 3.0, "mult": 3.0},
		],
	},
	"dropship": {
		"display": "DROPSHIP",
		"mesh": "dropship", "scale": 1.0,
		"hp": 200.0, "radius": 10.0, "speed": 95.0,
		"alt": [90.0, 300.0], "dist": [1400.0, 1900.0],
		"behavior": "beeline", "agility": 0.3,
		"threat": 20.0, "score": 550, "cost": 3.5, "min_wave": 6,
		"weak_points": [
			{"pos": Vector3(-10.0, 2.2, 1.0), "radius": 3.0, "mult": 2.5},
			{"pos": Vector3(10.0, 2.2, 1.0), "radius": 3.0, "mult": 2.5},
		],
	},
	"gunship": {
		"display": "ASSAULT GUNSHIP",
		"mesh": "gunship", "scale": 1.0,
		"hp": 620.0, "radius": 17.0, "speed": 70.0,
		"alt": [120.0, 340.0], "dist": [1600.0, 2100.0],
		"behavior": "strafe", "agility": 0.22,
		"threat": 34.0, "score": 1500, "cost": 7.0, "min_wave": 8,
		"weak_points": [
			{"pos": Vector3(-3.0, 0.0, 17.0), "radius": 3.5, "mult": 3.0},
			{"pos": Vector3(3.0, 0.0, 17.0), "radius": 3.5, "mult": 3.0},
			{"pos": Vector3(-8.0, 1.0, 6.0), "radius": 3.5, "mult": 2.0},
			{"pos": Vector3(8.0, 1.0, 6.0), "radius": 3.5, "mult": 2.0},
		],
		"carrier": {"type": "drone", "count": 4, "interval": 6.0},
	},
	"orb": {
		"display": "UNKNOWN / NON-BALLISTIC",
		"mesh": "orb", "scale": 1.0,
		"hp": 150.0, "radius": 7.5, "speed": 150.0,
		"alt": [150.0, 600.0], "dist": [1200.0, 1800.0],
		"behavior": "weave", "agility": 1.0,
		"threat": 18.0, "score": 900, "cost": 4.0, "min_wave": 9,
	},
	"mothership": {
		"display": "MOTHERSHIP / SKY CARRIER",
		"mesh": "mothership", "scale": 1.0,
		"hp": 14000.0, "radius": 186.0, "speed": 30.0,
		"alt": [420.0, 520.0], "dist": [2400.0, 2600.0],
		"standoff": [1100.0, 1300.0],
		"behavior": "station", "agility": 0.05,
		"threat": 100.0, "score": 15000, "cost": 30.0, "min_wave": 8,
		"boss": true,
		# Chain of spheres down the hull, then gondola, pods and tail.
		"hit_volumes": [
			{"pos": Vector3(0, 0, -160), "radius": 15.6},
			{"pos": Vector3(0, 0, -128), "radius": 23.9},
			{"pos": Vector3(0, 0, -96), "radius": 28.8},
			{"pos": Vector3(0, 0, -64), "radius": 31.8},
			{"pos": Vector3(0, 0, -32), "radius": 33.5},
			{"pos": Vector3(0, 0, 0), "radius": 34.0},
			{"pos": Vector3(0, 0, 32), "radius": 33.5},
			{"pos": Vector3(0, 0, 64), "radius": 31.8},
			{"pos": Vector3(0, 0, 96), "radius": 28.8},
			{"pos": Vector3(0, 0, 128), "radius": 23.9},
			{"pos": Vector3(0, 0, 160), "radius": 15.6},
			{"pos": Vector3(0, -38, -70), "radius": 12.0},
			{"pos": Vector3(0, -38, -40), "radius": 12.0},
			{"pos": Vector3(0, -38, -10), "radius": 12.0},
			{"pos": Vector3(-50, -6, -55), "radius": 10.0},
			{"pos": Vector3(50, -6, -55), "radius": 10.0},
			{"pos": Vector3(-50, -6, 60), "radius": 10.0},
			{"pos": Vector3(50, -6, 60), "radius": 10.0},
			{"pos": Vector3(0, 39, 150), "radius": 16.0},
			{"pos": Vector3(0, -39, 150), "radius": 16.0},
			{"pos": Vector3(39, 0, 150), "radius": 16.0},
			{"pos": Vector3(-39, 0, 150), "radius": 16.0},
		],
		"weak_points": [
			# Engine pods.
			{"pos": Vector3(-50, -6, -55), "radius": 12.0, "mult": 3.0},
			{"pos": Vector3(50, -6, -55), "radius": 12.0, "mult": 3.0},
			{"pos": Vector3(-50, -6, 60), "radius": 12.0, "mult": 3.0},
			{"pos": Vector3(50, -6, 60), "radius": 12.0, "mult": 3.0},
			# Open launch bay.
			{"pos": Vector3(0, -35, 70), "radius": 22.0, "mult": 2.5},
			# Bridge.
			{"pos": Vector3(0, -35, -84), "radius": 10.0, "mult": 3.0},
		],
		# Drops three craft at a time out of the belly bay.
		"carrier": {
			"types": ["drone", "drone", "jet"],
			"count": 8, "burst": 3, "interval": 8.0, "first": 7.0,
			"bays": [Vector3(0, -40, 50), Vector3(0, -40, 70), Vector3(0, -40, 90)],
		},
	},
	"leviathan": {
		"display": "CAPITAL / LEVIATHAN",
		"mesh": "leviathan", "scale": 1.0,
		"hp": 4200.0, "radius": 122.0, "speed": 32.0,
		"alt": [220.0, 380.0], "dist": [2600.0, 3000.0],
		"behavior": "capital", "agility": 0.05,
		"threat": 100.0, "score": 12000, "cost": 26.0, "min_wave": 12,
		"boss": true,
		"hit_volumes": [
			{"pos": Vector3(0, 0, -105), "radius": 15.0},
			{"pos": Vector3(0, 0, -80), "radius": 15.0},
			{"pos": Vector3(0, 0, -55), "radius": 15.0},
			{"pos": Vector3(0, 0, -30), "radius": 15.0},
			{"pos": Vector3(0, 0, -5), "radius": 15.0},
			{"pos": Vector3(0, 0, 20), "radius": 15.0},
			{"pos": Vector3(0, 0, 45), "radius": 15.0},
			{"pos": Vector3(0, 0, 70), "radius": 15.0},
			{"pos": Vector3(0, 0, 88), "radius": 16.0},
			{"pos": Vector3(-19, 12, 30), "radius": 13.0},
			{"pos": Vector3(19, 12, 30), "radius": 13.0},
			{"pos": Vector3(0, 17, 40), "radius": 9.0},
		],
		"weak_points": [
			# Drive bells at the stern - the intended kill shot.
			{"pos": Vector3(0.0, 0.0, 86.0), "radius": 16.0, "mult": 4.0},
			# Radiator fins.
			{"pos": Vector3(-19.0, 12.0, 30.0), "radius": 13.0, "mult": 2.5},
			{"pos": Vector3(19.0, 12.0, 30.0), "radius": 13.0, "mult": 2.5},
			# Bridge.
			{"pos": Vector3(0.0, 17.0, 40.0), "radius": 8.0, "mult": 3.0},
		],
		"carrier": {"type": "jet", "count": 8, "interval": 7.0},
	},
	"dreadnought": {
		"display": "ORBITAL / DREADNOUGHT",
		"mesh": "dreadnought", "scale": 1.6,
		"hp": 50000.0, "radius": 1120.0, "speed": 5.0,
		"alt": [1050.0, 1150.0], "dist": [1300.0, 1400.0],
		"behavior": "station", "agility": 0.02,
		"threat": 100.0, "score": 40000, "cost": 45.0, "min_wave": 16,
		"boss": true,
		# Arrives out of nowhere instead of flying in, and falls out of the sky
		# when it dies instead of vanishing.
		"warp": {"distance": 9000.0, "unknown": "UNKNOWN SIGNATURE"},
		"wreck": true,
		"fire_scale": 3.5,
		# Hull blocks as two columns of spheres each, then the bow prongs,
		# collars, sail, radiator wings and drive bells.
		"hit_volumes": [
			{"pos": Vector3(-55, 0, 240), "radius": 70.0},
			{"pos": Vector3(55, 0, 240), "radius": 70.0},
			{"pos": Vector3(-55, 0, 310), "radius": 70.0},
			{"pos": Vector3(55, 0, 310), "radius": 70.0},
			{"pos": Vector3(-55, 0, 380), "radius": 70.0},
			{"pos": Vector3(55, 0, 380), "radius": 70.0},
			{"pos": Vector3(-55, 0, 450), "radius": 70.0},
			{"pos": Vector3(55, 0, 450), "radius": 70.0},
			{"pos": Vector3(-55, 0, 520), "radius": 70.0},
			{"pos": Vector3(55, 0, 520), "radius": 70.0},
			{"pos": Vector3(-35, 0, -120), "radius": 55.0},
			{"pos": Vector3(35, 0, -120), "radius": 55.0},
			{"pos": Vector3(-35, 0, -60), "radius": 55.0},
			{"pos": Vector3(35, 0, -60), "radius": 55.0},
			{"pos": Vector3(-35, 0, 0), "radius": 55.0},
			{"pos": Vector3(35, 0, 0), "radius": 55.0},
			{"pos": Vector3(-35, 0, 60), "radius": 55.0},
			{"pos": Vector3(35, 0, 60), "radius": 55.0},
			{"pos": Vector3(-35, 0, 120), "radius": 55.0},
			{"pos": Vector3(35, 0, 120), "radius": 55.0},
			{"pos": Vector3(-35, 0, 175), "radius": 55.0},
			{"pos": Vector3(35, 0, 175), "radius": 55.0},
			{"pos": Vector3(-20, 0, -420), "radius": 42.0},
			{"pos": Vector3(20, 0, -420), "radius": 42.0},
			{"pos": Vector3(-20, 0, -370), "radius": 42.0},
			{"pos": Vector3(20, 0, -370), "radius": 42.0},
			{"pos": Vector3(-20, 0, -320), "radius": 42.0},
			{"pos": Vector3(20, 0, -320), "radius": 42.0},
			{"pos": Vector3(-20, 0, -270), "radius": 42.0},
			{"pos": Vector3(20, 0, -270), "radius": 42.0},
			{"pos": Vector3(-20, 0, -220), "radius": 42.0},
			{"pos": Vector3(20, 0, -220), "radius": 42.0},
			{"pos": Vector3(-20, 0, -170), "radius": 42.0},
			{"pos": Vector3(20, 0, -170), "radius": 42.0},
			{"pos": Vector3(-62, 0, -640), "radius": 30.0},
			{"pos": Vector3(62, 0, -640), "radius": 30.0},
			{"pos": Vector3(-62, 0, -600), "radius": 30.0},
			{"pos": Vector3(62, 0, -600), "radius": 30.0},
			{"pos": Vector3(-62, 0, -560), "radius": 30.0},
			{"pos": Vector3(62, 0, -560), "radius": 30.0},
			{"pos": Vector3(-62, 0, -520), "radius": 30.0},
			{"pos": Vector3(62, 0, -520), "radius": 30.0},
			{"pos": Vector3(-62, 0, -480), "radius": 30.0},
			{"pos": Vector3(62, 0, -480), "radius": 30.0},
			{"pos": Vector3(-62, 0, -440), "radius": 30.0},
			{"pos": Vector3(62, 0, -440), "radius": 30.0},
			{"pos": Vector3(-62, 0, -405), "radius": 30.0},
			{"pos": Vector3(62, 0, -405), "radius": 30.0},
			{"pos": Vector3(0, 0, -425), "radius": 24.0},
			{"pos": Vector3(115.0, 0.0, -60), "radius": 14.0},
			{"pos": Vector3(81.3, 81.3, -60), "radius": 14.0},
			{"pos": Vector3(0.0, 115.0, -60), "radius": 14.0},
			{"pos": Vector3(-81.3, 81.3, -60), "radius": 14.0},
			{"pos": Vector3(-115.0, 0.0, -60), "radius": 14.0},
			{"pos": Vector3(-81.3, -81.3, -60), "radius": 14.0},
			{"pos": Vector3(-0.0, -115.0, -60), "radius": 14.0},
			{"pos": Vector3(81.3, -81.3, -60), "radius": 14.0},
			{"pos": Vector3(115.0, 0.0, 60), "radius": 14.0},
			{"pos": Vector3(81.3, 81.3, 60), "radius": 14.0},
			{"pos": Vector3(0.0, 115.0, 60), "radius": 14.0},
			{"pos": Vector3(-81.3, 81.3, 60), "radius": 14.0},
			{"pos": Vector3(-115.0, 0.0, 60), "radius": 14.0},
			{"pos": Vector3(-81.3, -81.3, 60), "radius": 14.0},
			{"pos": Vector3(-0.0, -115.0, 60), "radius": 14.0},
			{"pos": Vector3(81.3, -81.3, 60), "radius": 14.0},
			{"pos": Vector3(78.0, 0.0, -260), "radius": 11.0},
			{"pos": Vector3(55.2, 55.2, -260), "radius": 11.0},
			{"pos": Vector3(0.0, 78.0, -260), "radius": 11.0},
			{"pos": Vector3(-55.2, 55.2, -260), "radius": 11.0},
			{"pos": Vector3(-78.0, 0.0, -260), "radius": 11.0},
			{"pos": Vector3(-55.2, -55.2, -260), "radius": 11.0},
			{"pos": Vector3(-0.0, -78.0, -260), "radius": 11.0},
			{"pos": Vector3(55.2, -55.2, -260), "radius": 11.0},
			{"pos": Vector3(0, 100, 270), "radius": 38.0},
			{"pos": Vector3(0, 100, 330), "radius": 38.0},
			{"pos": Vector3(0, 185, 272), "radius": 36.0},
			{"pos": Vector3(-200, 20, 350), "radius": 30.0},
			{"pos": Vector3(-200, 20, 450), "radius": 30.0},
			{"pos": Vector3(-150, 20, 350), "radius": 30.0},
			{"pos": Vector3(-150, 20, 450), "radius": 30.0},
			{"pos": Vector3(150, 20, 350), "radius": 30.0},
			{"pos": Vector3(150, 20, 450), "radius": 30.0},
			{"pos": Vector3(200, 20, 350), "radius": 30.0},
			{"pos": Vector3(200, 20, 450), "radius": 30.0},
			{"pos": Vector3(-70, -30, 590), "radius": 28.0},
			{"pos": Vector3(-70, 30, 590), "radius": 28.0},
			{"pos": Vector3(0, -30, 590), "radius": 28.0},
			{"pos": Vector3(0, 30, 590), "radius": 28.0},
			{"pos": Vector3(70, -30, 590), "radius": 28.0},
			{"pos": Vector3(70, 30, 590), "radius": 28.0},
		],
		"weak_points": [
			# Drive bells: the kill shot, if you can see the stern.
			{"pos": Vector3(0, 0, 590), "radius": 110.0, "mult": 3.0},
			# Bow emitter between the prongs.
			{"pos": Vector3(0, 0, -440), "radius": 30.0, "mult": 4.0},
			# Bridge on the sail.
			{"pos": Vector3(0, 185, 272), "radius": 40.0, "mult": 3.0},
			# Open hangar slots on the belly.
			{"pos": Vector3(0, -52, -90), "radius": 34.0, "mult": 2.5},
			{"pos": Vector3(0, -52, -10), "radius": 34.0, "mult": 2.5},
			{"pos": Vector3(0, -52, 70), "radius": 34.0, "mult": 2.5},
			{"pos": Vector3(0, -52, 150), "radius": 34.0, "mult": 2.5},
			# Radiator wings.
			{"pos": Vector3(-170, 20, 400), "radius": 85.0, "mult": 1.8},
			{"pos": Vector3(170, 20, 400), "radius": 85.0, "mult": 1.8},
		],
		# Three craft at a time out of the hangar slots, for as long as it lives.
		"carrier": {
			"types": ["jet", "jet", "drone", "drone", "drone", "dropship", "gunship"],
			"count": 14, "burst": 3, "interval": 10.0, "first": 6.0,
			"bays": [Vector3(0, -62, -90), Vector3(0, -62, -10), Vector3(0, -62, 70), Vector3(0, -62, 150)],
		},
	},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["drone"])


static func ids_available_at(wave: int) -> Array:
	var out: Array = []
	for id in TYPES.keys():
		if int(TYPES[id].get("min_wave", 1)) <= wave:
			out.append(id)
	return out

//Ported from /vg/station13, which was in turn forked from baystation12;
//Please do not bother them with bugs from this port, however, as it has been modified quite a bit.
//Modifications include removing the world-ending full supermatter variation, and leaving only the shard.

#define NITROGEN_RETARDATION_FACTOR 4        //Higher == N2 slows reaction more
#define THERMAL_RELEASE_MODIFIER 10                //Higher == less heat released during reaction
#define PLASMA_RELEASE_MODIFIER 1500                //Higher == less plasma released by reaction
#define OXYGEN_RELEASE_MODIFIER 750        //Higher == less oxygen released at high temperature/power
#define REACTION_POWER_MODIFIER 1.1                //Higher == more overall power


//These would be what you would get at point blank, decreases with distance
#define DETONATION_RADS 200
#define DETONATION_HALLUCINATION 600


#define WARNING_DELAY 30 		//seconds between warnings.

/obj/machinery/power/supermatter_shard
	name = "supermatter shard"
	desc = "A strangely translucent and iridescent crystal that looks like it used to be part of a larger structure. \red You get headaches just from looking at it."
	icon = 'icons/obj/supermatter.dmi'
	icon_state = "darkmatter_shard"
	density = 1
	anchored = 0
	luminosity = 4


	var/gasefficency = 0.125

	var/base_icon_state = "darkmatter_shard"

	var/damage = 0
	var/damage_archived = 0
	var/safe_alert = "Crystalline hyperstructure returning to safe operating levels."
	var/warning_point = 50
	var/warning_alert = "Danger! Crystal hyperstructure instability!"
	var/emergency_point = 500
	var/emergency_alert = "CRYSTAL DELAMINATION IMMINENT."
	var/explosion_point = 900

	var/emergency_issued = 0

	var/explosion_power = 8

	var/lastwarning = 0				// Time in 1/10th of seconds since the last sent warning
	var/power = 0

	var/oxygen = 0					// Moving this up here for easier debugging.

	//Temporary values so that we can optimize this
	//How much the bullets damage should be multiplied by when it is added to the internal variables
	var/config_bullet_energy = 2
	//How much of the power is left after processing is finished?
//	var/config_power_reduction_per_tick = 0.5
	//How much hallucination should it produce per unit of power?
	var/config_hallucination_power = 0.1

	var/obj/item/device/radio/radio


/obj/machinery/power/supermatter_shard/New()
	. = ..()
	radio = new(src)
	radio.listening = 0


/obj/machinery/power/supermatter_shard/Destroy()
	qdel(radio)
	. = ..()

/obj/machinery/power/supermatter_shard/proc/explode()
	explosion(get_turf(src), explosion_power, explosion_power * 2, explosion_power * 3, explosion_power * 4, 1)
	qdel(src)
	return

/obj/machinery/power/supermatter_shard/process()
	var/turf/L = loc

	if(isnull(L))		// We have a null turf...something is wrong, stop processing this entity.
		return PROCESS_KILL

	if(!istype(L)) 	//We are in a crate or somewhere that isn't turf, if we return to turf resume processing but for now.
		return  //Yeah just stop.

	if(istype(L, /turf/space))	// Stop processing this stuff if we've been ejected.
		return

	if(damage > warning_point) // while the core is still damaged and it's still worth noting its status
		if((world.timeofday - lastwarning) / 10 >= WARNING_DELAY)
			var/stability = num2text(round((damage / explosion_point) * 100))

			if(damage > emergency_point)
				radio.talk_into(src, "[emergency_alert] Instability: [stability]%")
				lastwarning = world.timeofday

			else if(damage >= damage_archived) // The damage is still going up
				radio.talk_into(src, "[warning_alert] Instability: [stability]%")
				lastwarning = world.timeofday - 150

			else                                                 // Phew, we're safe
				radio.talk_into(src, "[safe_alert]")
				lastwarning = world.timeofday

		if(damage > explosion_point)
			for(var/mob/living/mob in living_mob_list)
				if(istype(mob, /mob/living/carbon/human))
					//Hilariously enough, running into a closet should make you get hit the hardest.
					var/mob/living/carbon/human/H = mob
					H.hallucination += max(50, min(300, DETONATION_HALLUCINATION * sqrt(1 / (get_dist(mob, src) + 1)) ) )
				var/rads = DETONATION_RADS * sqrt( 1 / (get_dist(mob, src) + 1) )
				mob.apply_effect(rads, IRRADIATE)

			explode()

	//Ok, get the air from the turf
	var/datum/gas_mixture/env = L.return_air()

	//Remove gas from surrounding area
	var/datum/gas_mixture/removed = env.remove(gasefficency * env.total_moles())

	if(!removed || !removed.total_moles())
		damage += max((power-1600)/10, 0)
		power = min(power, 1600)
		return 1

	if (!removed)
		return 1

	damage_archived = damage
	damage = max( damage + ( (removed.temperature - 800) / 150 ) , 0 )
	//Ok, 100% oxygen atmosphere = best reaction
	//Maxes out at 100% oxygen pressure
	oxygen = max(min((removed.oxygen - (removed.nitrogen * NITROGEN_RETARDATION_FACTOR)) / MOLES_CELLSTANDARD, 1), 0)

	var/temp_factor = 100

	if(oxygen > 0.8)
		// with a perfect gas mix, make the power less based on heat
		icon_state = "[base_icon_state]_glow"
	else
		// in normal mode, base the produced energy around the heat
		temp_factor = 60
		icon_state = base_icon_state

	power = max( (removed.temperature * temp_factor / T0C) * oxygen + power, 0) //Total laser power plus an overload

	//We've generated power, now let's transfer it to the collectors for storing/usage
	transfer_energy()

	var/device_energy = power * REACTION_POWER_MODIFIER

	//To figure out how much temperature to add each tick, consider that at one atmosphere's worth
	//of pure oxygen, with all four lasers firing at standard energy and no N2 present, at room temperature
	//that the device energy is around 2140. At that stage, we don't want too much heat to be put out
	//Since the core is effectively "cold"

	//Also keep in mind we are only adding this temperature to (efficiency)% of the one tile the rock
	//is on. An increase of 4*C @ 25% efficiency here results in an increase of 1*C / (#tilesincore) overall.
	removed.temperature += (device_energy / THERMAL_RELEASE_MODIFIER)

	removed.temperature = max(0, min(removed.temperature, 2500))

	//Calculate how much gas to release
	removed.toxins += max(device_energy / PLASMA_RELEASE_MODIFIER, 0)

	removed.oxygen += max((device_energy + removed.temperature - T0C) / OXYGEN_RELEASE_MODIFIER, 0)

	env.merge(removed)

	for(var/mob/living/carbon/human/l in view(src, min(7, round(power ** 0.25)))) // If they can see it without mesons on.  Bad on them.
		if(!istype(l.glasses, /obj/item/clothing/glasses/meson))
			l.hallucination = max(0, min(200, l.hallucination + power * config_hallucination_power * sqrt( 1 / max(1,get_dist(l, src)) ) ) )

	for(var/mob/living/l in range(src, round((power / 100) ** 0.25)))
		var/rads = (power / 10) * sqrt( 1 / get_dist(l, src) )
		l.apply_effect(rads, IRRADIATE)

	power -= (power/500)**3

	return 1


/obj/machinery/power/supermatter_shard/bullet_act(var/obj/item/projectile/Proj)
	var/turf/L = loc
	if(!istype(L))		// We don't run process() when we are in space
		return 0	// This stops people from being able to really power up the supermatter
				// Then bring it inside to explode instantly upon landing on a valid turf.


	if(Proj.flag != "bullet")
		power += Proj.damage * config_bullet_energy
	else
		damage += Proj.damage * config_bullet_energy
	return 0


/obj/machinery/power/supermatter_shard/attack_paw(mob/user as mob)
	return attack_hand(user)


/obj/machinery/power/supermatter_shard/attack_robot(mob/user as mob)
	if(Adjacent(user))
		return attack_hand(user)
	else
		user << "<span class = \"warning\">You attempt to interface with the control circuits but find they are not connected to your network. Maybe in a future firmware update.</span>"
	return

/obj/machinery/power/supermatter_shard/attack_ai(mob/user as mob)
	user << "<span class = \"warning\">You attempt to interface with the control circuits but find they are not connected to your network. Maybe in a future firmware update.</span>"

/obj/machinery/power/supermatter_shard/attack_hand(mob/user as mob)
	user.visible_message("<span class=\"warning\">\The [user] reaches out and touches \the [src], inducing a resonance... \his body starts to glow and bursts into flames before flashing into ash.</span>",\
		"<span class=\"danger\">You reach out and touch \the [src]. Everything starts burning and all you can hear is ringing. Your last thought is \"That was not a wise decision.\"</span>",\
		"<span class=\"warning\">You hear an unearthly noise as a wave of heat washes over you.</span>")

	playsound(get_turf(src), 'sound/effects/supermatter.ogg', 50, 1)

	Consume(user)

/obj/machinery/power/supermatter_shard/proc/transfer_energy()
	for(var/obj/machinery/power/rad_collector/R in rad_collectors)
		if(get_dist(R, src) <= 15) // Better than using orange() every process
			R.receive_pulse(power)
	return

/obj/machinery/power/supermatter_shard/attackby(obj/item/weapon/W as obj, mob/living/user as mob)
	if(user.drop_item(W))
		Consume(W)
		user.visible_message("<span class=\"warning\">As [user] touches \the [src] with \a [W], silence fills the room...</span>",\
			"<span class=\"danger\">You touch \the [src] with \the [W], and everything suddenly goes silent.\"</span>\n<span class=\"notice\">\The [W] flashes into dust as you flinch away from \the [src].</span>",\
			"<span class=\"warning\">Everything suddenly goes silent.</span>")

		playsound(get_turf(src), 'sound/effects/supermatter.ogg', 50, 1)

		user.apply_effect(150, IRRADIATE)


/obj/machinery/power/supermatter_shard/Bumped(atom/AM as mob|obj)
	if(istype(AM, /mob/living))
		AM.visible_message("<span class=\"warning\">\The [AM] slams into \the [src] inducing a resonance... \his body starts to glow and catch flame before flashing into ash.</span>",\
		"<span class=\"danger\">You slam into \the [src] as your ears are filled with unearthly ringing. Your last thought is \"Oh, fuck.\"</span>",\
		"<span class=\"warning\">You hear an unearthly noise as a wave of heat washes over you.</span>")
	else
		AM.visible_message("<span class=\"warning\">\The [AM] smacks into \the [src] and rapidly flashes to ash.</span>",\
		"<span class=\"warning\">You hear a loud crack as you are washed with a wave of heat.</span>")

	playsound(get_turf(src), 'sound/effects/supermatter.ogg', 50, 1)

	Consume(AM)


/obj/machinery/power/supermatter_shard/proc/Consume(atom/movable/AM)
	if(istype(AM, /mob/living))
		var/mob/living/user = AM
		user.dust()
		power += 200
	else
		qdel(AM)

	power += 200

	//Some poor sod got eaten, go ahead and irradiate people nearby.
	for(var/mob/living/L in range(10))
		var/rads = 500 * sqrt( 1 / (get_dist(L, src) + 1) )
		L.apply_effect(rads, IRRADIATE)
		if(L in view())
			L.show_message("<span class=\"warning\">As \the [src] slowly stops resonating, you find your skin covered in new radiation burns.</span>", 1,\
				"<span class=\"warning\">The unearthly ringing subsides and you notice you have new radiation burns.</span>", 2)
		else
			L.show_message("<span class=\"warning\">You hear an uneartly ringing and notice your skin is covered in fresh radiation burns.</span>", 2)

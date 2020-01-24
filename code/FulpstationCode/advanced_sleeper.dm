/obj/machinery/adv_sleep_console
	name = "sleeper console"
	icon = 'icons/obj/machines/sleeper.dmi'
	icon_state = "console"
	density = FALSE

/obj/machinery/adv_sleeper
	name = "advanced sleeper"
	desc = "An enclosed machine used to stabilize and heal patients, this one is advanced and only requires power input."
	icon = 'icons/obj/machines/sleeper.dmi'
	icon_state = "sleeper"
	density = FALSE
	state_open = TRUE
	circuit = /obj/item/circuitboard/machine/adv_sleeper
	ui_x = 375
	ui_y = 550

	var/obj/item/stock_parts/cell/cell
	var/efficiency = 0.1
	var/amount = 30
	var/recharge_amount = 10
	var/recharge_counter = 0
	var/min_health = -50
	var/controls_inside = FALSE
	var/list/basic_chems = list(
		/datum/reagent/medicine/C2/libital, /datum/reagent/medicine/C2/aiuri,
		/datum/reagent/medicine/C2/lenturi, /datum/reagent/medicine/granibitaluri, /datum/reagent/medicine/C2/multiver
		/datum/reagent/medicine/C2/syriniver, /datum/reagent/medicine/C2/tirimol, /datum/reagent/medicine/C2/convermol,
		/datum/reagent/medicine/trophazole, /datum/reagent/medicine/rhigoxane
	)
	var/list/upgraded_chems = list(
		/datum/reagent/medicine/sal_acid, /datum/reagent/medicine/oxandrolone, /datum/reagent/medicine/salbutamol,
		/datum/reagent/medicine/pen_acid, /datum/reagent/medicine/atropine, /datum/reagent/medicine/calomel,
		/datum/reagent/medicine/salglu_solution, /datum/reagent/medicine/spaceacillin, /datum/reagent/medicine/potass_iodide,
		/datum/reagent/medicine/epinephrine, /datum/reagent/medicine/mannitol
	)
	var/list/t5_chems = list(
		/datum/reagent/medicine/CF/bicaridine, /datum/reagent/medicine/CF/kelotane, /datum/reagent/medicine/CF/antitoxin,
		/datum/reagent/medicine/CF/tricordrazine, /datum/reagent/medicine/omnizine, /datum/reagent/medicine/neurine,
		/datum/reagent/medicine/oculine, /datum/reagent/medicine/inacusiate, /datum/reagent/medicine/synaptizine,
		/datum/reagent/medicine/C2/penthrite, /datum/reagent/medicine/higadrite
	)
	var/list/abductor_chems = list(
		/datum/reagent/medicine/omnizine, /datum/reagent/medicine/rezadone, /datum/reagent/medicine/silibinin,
		/datum/reagent/medicine/polypyr, /datum/reagent/medicine/cordiolis_hepatico, /datum/reagent/medicine/mutadone
	)
	var/list/emagged_reagents = list(
		/datum/reagent/toxin/carpotoxin,
		/datum/reagent/medicine/mine_salve,
		/datum/reagent/medicine/morphine,
		/datum/reagent/drug/space_drugs,
		/datum/reagent/toxin
	)
	var/list/chem_buttons	//Used when emagged to scramble which chem is used, eg: mutadone -> morphine
	var/scrambled_chems = FALSE //Are chem buttons scrambled? used as a warning
	var/enter_message = "<span class='notice'><b>You feel cool air surround you. You go numb as your senses turn inward.</b></span>"
	payment_department = ACCOUNT_MED
	fair_market_price = 5

/obj/machinery/adv_sleeper/Initialize(mapload)
	. = ..()
	if(mapload)
		component_parts -= circuit
		QDEL_NULL(circuit)
	occupant_typecache = GLOB.typecache_living

	update_icon()
	reset_chem_buttons()

/obj/machinery/adv_sleeper/RefreshParts()
	recharge_amount = initial(recharge_amount)
	var/neweff = 0.0666666
	for(var/obj/item/stock_parts/cell/P in component_parts)
		cell = P
	for(var/obj/item/stock_parts/matter_bin/B in component_parts)
		neweff += 0.0166666666*B.rating
	for(var/obj/item/stock_parts/capacitor/C in component_parts)
		recharge_amount *= C.rating
	for(var/obj/item/stock_parts/manipulator/M in component_parts)
		if (M.rating > 3 && B.rating > 3)
			basic_chems |= upgraded_chems
		if (M.rating > 4 && B.rating > 4)
			basic_chems = upgraded_chems
			basic_chems |= t5_chems
			if(ABDUCTOR_UNLOCK)
				basic_chems |= abductor_chems

	efficiency = round(neweff, 0.01)
	reset_chem_buttons()

/obj/machinery/adv_sleeper/update_icon_state()
	if(state_open)
		icon_state = "[initial(icon_state)]-open"
	else
		icon_state = initial(icon_state)

/obj/machinery/adv_sleeper/container_resist(mob/living/user)
	visible_message("<span class='notice'>[occupant] emerges from [src]!</span>",
		"<span class='notice'>You climb out of [src]!</span>")
	open_machine()

/obj/machinery/adv_sleeper/Exited(atom/movable/user)
	if (!state_open && user == occupant)
		container_resist(user)

/obj/machinery/adv_sleeper/relaymove(mob/user)
	if (!state_open)
		container_resist(user)

/obj/machinery/adv_sleeper/open_machine()
	if(!state_open && !panel_open)
		flick("[initial(icon_state)]-anim", src)
		..()

/obj/machinery/adv_sleeper/close_machine(mob/user)
	if((isnull(user) || istype(user)) && state_open && !panel_open)
		flick("[initial(icon_state)]-anim", src)
		..(user)
		var/mob/living/mob_occupant = occupant
		if(mob_occupant && mob_occupant.stat != DEAD)
			to_chat(occupant, "[enter_message]")

/obj/machinery/adv_sleeper/emp_act(severity)
	. = ..()
	if (. & EMP_PROTECT_SELF)
		return
	if(is_operational() && occupant)
		open_machine()

/obj/machinery/adv_sleeper/MouseDrop_T(mob/target, mob/user)
	if(user.stat || !Adjacent(user) || !user.Adjacent(target) || !iscarbon(target) || !user.IsAdvancedToolUser())
		return
	if(isliving(user))
		var/mob/living/L = user
		if(!(L.mobility_flags & MOBILITY_STAND))
			return
	close_machine(target)

/obj/machinery/adv_sleeper/screwdriver_act(mob/living/user, obj/item/I)
	. = TRUE
	if(..())
		return
	if(occupant)
		to_chat(user, "<span class='warning'>[src] is currently occupied!</span>")
		return
	if(state_open)
		to_chat(user, "<span class='warning'>[src] must be closed to [panel_open ? "close" : "open"] its maintenance hatch!</span>")
		return
	if(default_deconstruction_screwdriver(user, "[initial(icon_state)]-o", initial(icon_state), I))
		return
	return FALSE

/obj/machinery/adv_sleeper/wrench_act(mob/living/user, obj/item/I)
	. = ..()
	if(default_change_direction_wrench(user, I))
		return TRUE

/obj/machinery/adv_sleeper/crowbar_act(mob/living/user, obj/item/I)
	. = ..()
	if(default_pry_open(I))
		return TRUE
	if(default_deconstruction_crowbar(I))
		return TRUE

/obj/machinery/adv_sleeper/default_pry_open(obj/item/I) //wew
	. = !(state_open || panel_open || (flags_1 & NODECONSTRUCT_1)) && I.tool_behaviour == TOOL_CROWBAR
	if(.)
		I.play_tool_sound(src, 50)
		visible_message("<span class='notice'>[usr] pries open [src].</span>", "<span class='notice'>You pry open [src].</span>")
		open_machine()

/obj/machinery/adv_sleeper/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, \
									datum/tgui/master_ui = null, datum/ui_state/state = GLOB.notcontained_state)

	if(controls_inside && state == GLOB.notcontained_state)
		state = GLOB.default_state // If it has a set of controls on the inside, make it actually controllable by the mob in it.

	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "sleeper", name, ui_x, ui_y, master_ui, state)
		ui.open()

/obj/machinery/adv_sleeper/AltClick(mob/user)
	if(!user.canUseTopic(src, !issilicon(user)))
		return
	if(state_open)
		close_machine()
	else
		open_machine()

/obj/machinery/adv_sleeper/examine(mob/user)
	. = ..()
	. += "<span class='notice'>Alt-click [src] to [state_open ? "close" : "open"] it.</span>"

/obj/machinery/adv_sleeper/process()
	..()
	check_nap_violations()

/obj/machinery/adv_sleeper/nap_violation(mob/violator)
	open_machine()

/obj/machinery/adv_sleeper/ui_data()
	var/list/data = list()
	data["amount"] = amount
	data["energy"] = cell.charge ? cell.charge * efficiency : "0" //To prevent NaN in the UI.
	data["maxEnergy"] = cell.maxcharge * efficiency
	data["occupied"] = occupant ? 1 : 0
	data["open"] = state_open

	data["chems"] = list()
	for(var/chem in available_chems)
		var/datum/reagent/R = GLOB.chemical_reagents_list[chem]
		data["chems"] += list(list("name" = R.name, "id" = R.type, "allowed" = chem_allowed(chem)))

	data["occupant"] = list()
	var/mob/living/mob_occupant = occupant
	if(mob_occupant)
		data["occupant"]["name"] = mob_occupant.name
		switch(mob_occupant.stat)
			if(CONSCIOUS)
				data["occupant"]["stat"] = "Conscious"
				data["occupant"]["statstate"] = "good"
			if(SOFT_CRIT)
				data["occupant"]["stat"] = "Conscious"
				data["occupant"]["statstate"] = "average"
			if(UNCONSCIOUS)
				data["occupant"]["stat"] = "Unconscious"
				data["occupant"]["statstate"] = "average"
			if(DEAD)
				data["occupant"]["stat"] = "Dead"
				data["occupant"]["statstate"] = "bad"
		data["occupant"]["health"] = mob_occupant.health
		data["occupant"]["maxHealth"] = mob_occupant.maxHealth
		data["occupant"]["minHealth"] = HEALTH_THRESHOLD_DEAD
		data["occupant"]["bruteLoss"] = mob_occupant.getBruteLoss()
		data["occupant"]["oxyLoss"] = mob_occupant.getOxyLoss()
		data["occupant"]["toxLoss"] = mob_occupant.getToxLoss()
		data["occupant"]["fireLoss"] = mob_occupant.getFireLoss()
		data["occupant"]["cloneLoss"] = mob_occupant.getCloneLoss()
		data["occupant"]["brainLoss"] = mob_occupant.getOrganLoss(ORGAN_SLOT_BRAIN)
		data["occupant"]["reagents"] = list()
		if(mob_occupant.reagents && mob_occupant.reagents.reagent_list.len)
			for(var/datum/reagent/R in mob_occupant.reagents.reagent_list)
				data["occupant"]["reagents"] += list(list("name" = R.name, "volume" = R.volume))
	return data

/obj/machinery/adv_sleeper/ui_act(action, params)
	if(..())
		return
	var/mob/living/mob_occupant = occupant
	check_nap_violations()
	switch(action)
		if("door")
			if(state_open)
				close_machine()
			else
				open_machine()
			. = TRUE
		if("inject")
			var/chem = text2path(params["chem"])
			if(!is_operational() || !mob_occupant || isnull(chem))
				return
			if(mob_occupant.health < min_health && chem != /datum/reagent/medicine/epinephrine)
				return
			if(inject_chem(chem, usr))
				. = TRUE
				if(scrambled_chems && prob(5))
					to_chat(usr, "<span class='warning'>Chemical system re-route detected, results may not be as expected!</span>")

/obj/machinery/adv_sleeper/emag_act(mob/user)
	scramble_chem_buttons()
	to_chat(user, "<span class='warning'>You scramble the sleeper's user interface!</span>")

/obj/machinery/adv_sleeper/proc/inject_chem(chem, mob/user)
	if((chem in available_chems) && chem_allowed(chem))
		occupant.reagents.add_reagent(chem_buttons[chem], 10) //emag effect kicks in here so that the "intended" chem is used for all checks, for extra FUUU
		if(user)
			log_combat(user, occupant, "injected [chem] into", addition = "via [src]")
		return TRUE

/obj/machinery/adv_sleeper/proc/chem_allowed(chem)
	var/mob/living/mob_occupant = occupant
	if(!mob_occupant || !mob_occupant.reagents)
		return
	var/amount = mob_occupant.reagents.get_reagent_amount(chem) + 10 <= 20 * efficiency
	var/occ_health = mob_occupant.health > min_health || chem == /datum/reagent/medicine/epinephrine
	return amount && occ_health

/obj/machinery/adv_sleeper/proc/reset_chem_buttons()
	scrambled_chems = FALSE
	LAZYINITLIST(chem_buttons)
	for(var/chem in available_chems)
		chem_buttons[chem] = chem

/obj/machinery/adv_sleeper/proc/scramble_chem_buttons()
	scrambled_chems = TRUE
	var/list/av_chem = available_chems.Copy()
	for(var/chem in av_chem)
		chem_buttons[chem] = pick_n_take(av_chem) //no dupes, allow for random buttons to still be correct


/obj/machinery/adv_sleeper/syndie
	icon_state = "sleeper_s"
	controls_inside = TRUE

/obj/machinery/adv_sleeper/syndie/fullupgrade/Initialize()
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/stock_parts/matter_bin/bluespace(null)
	component_parts += new /obj/item/stock_parts/manipulator/femto(null)
	component_parts += new /obj/item/stack/sheet/glass(null)
	component_parts += new /obj/item/stack/sheet/glass(null)
	component_parts += new /obj/item/stack/cable_coil(null)
	RefreshParts()

/obj/machinery/adv_sleeper/old
	icon_state = "oldpod"

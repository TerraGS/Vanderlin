/// Enables toxin healing
#define MIRACLE_HEAL_TOX (1<<0)
/// Enables oxyloss healing
#define MIRACLE_HEAL_OXY (1<<1)
/// Applies all healing to target bodypart
#define MIRACLE_HEAL_TARGET_ZONE (1<<2)
#define HEALING_DIVINE "divine"
#define HEALING_PROFANE "profane"
#define HEALING_HUNT "greathunt"

/datum/action/cooldown/spell/healing
	name = "Lesser Miracle"
	desc = "Call upon your patron to heal the wounds of yourself or others."
	button_icon_state = "lesserheal"
	sound = 'sound/magic/heal.ogg'
	charge_sound = 'sound/magic/holycharging.ogg'

	cast_range = 6
	spell_type = SPELL_MIRACLE
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	associated_skill = /datum/attribute/skill/magic/holy
	required_items = list(/obj/item/clothing/neck/psycross/silver/divine)

	charge_required = FALSE
	cooldown_time = 10 SECONDS
	spell_cost = 10

	/// Bitflags for additional healing specifications
	var/healing_flags = NONE
	/// Base healing before adjustments
	var/base_healing = 25
	/// Wound healing modifier
	var/wound_modifier = 0.25
	/// Blood healing amount
	var/blood_restoration = 0
	/// Energy restoration amount
	var/energy_restoration = 0
	/// Stuns undead
	var/stun_undead = FALSE
	/// What kind of healing is it?
	var/healing_type = HEALING_DIVINE
	/// Patron Restrictive
	var/patron_restrictive = FALSE

/datum/action/cooldown/spell/healing/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	return isliving(cast_on)

/datum/action/cooldown/spell/healing/cast(mob/living/cast_on)
	. = ..()
	var/datum/component/vampire_disguise/vampire_disguise = cast_on.GetComponent(/datum/component/vampire_disguise)
	switch(healing_type)
		if(HEALING_PROFANE)
			if(patron_restrictive && !(cast_on.patron in ALL_PROFANE_PATRONS))
				cast_on.visible_message(
					span_warning("The Inhumen Four sear the flesh of [cast_on]! a non-believer and weakling!"),
					span_notice("The Inhumen Four lash out at me with a wave of pain!"),
				)
				cast_on.emote("scream")
				return
		if(HEALING_DIVINE, HEALING_HUNT)
			if(cast_on.mob_biotypes & MOB_UNDEAD) //positive energy harms the undead
				if(!(cast_on.mind?.has_antag_datum(/datum/antagonist/vampire) && vampire_disguise?.disguised)) //vampire disguises are handled later
					if(cast_on.mind?.has_antag_datum(/datum/antagonist/vampire/lord))
						cast_on.visible_message(span_warning("[cast_on] overpowers being burned!"), span_greentext("I overpower being burned!"))
						return
					cast_on.visible_message(span_danger("[cast_on] is burned by holy light!"), span_userdanger("I'm burned by holy light!"))
					if(stun_undead)
						cast_on.Paralyze(5 SECONDS)
					cast_on.adjustFireLoss(base_healing)
					cast_on.adjust_divine_fire_stacks(1)
					cast_on.IgniteMob()
					return
		if(HEALING_DIVINE)
			if(HAS_TRAIT(cast_on, TRAIT_ASTRATA_CURSE))
				cast_on.visible_message(span_danger("[cast_on] recoils in pain!"), span_userdanger("Divine healing shuns me!"))
				cast_on.cursed_freak_out()
				return
			/// The Ten won't provide greater healing to centrist worshippers, they do not approve.
			/// This is ignored if they're already a divine servant, like a Templar, as undivded can only become church roles from round start.
			if(HAS_TRAIT(cast_on, TRAIT_DIVINE_CENTRIST) && !HAS_TRAIT(cast_on, TRAIT_DIVINE_SERVANT) && patron_restrictive)
				cast_on.visible_message(span_danger("[cast_on] recoils in shame!"), span_userdanger("The Ten reject my indecisiveness!"))
				cast_on.cursed_freak_out()
				return
			if(((cast_on.real_name in GLOB.excommunicated_players) || (cast_on.real_name in GLOB.heretical_players)) && !HAS_TRAIT(cast_on, TRAIT_FANATICAL))
				cast_on.visible_message(
					span_warning("The angry Ten sear the flesh of [cast_on]! a foolish blasphemer and heretic!"),
					span_notice("I am despised by the Ten, rejected, and they remind me just how unlovable I am with a wave of pain!"),
				)
				cast_on.emote("scream")
				return

	if(isliving(owner))
		var/mob/living/living_owner = owner
		if(living_owner.patron)
			if(istype(living_owner.patron, /datum/patron/godless))
				cast_on.visible_message(span_info("No Gods answer these prayers."), span_notice("No Gods answer these prayers."))
				return
			else if(living_owner.patron.type == (/datum/patron/divine/centrist || /datum/patron/inhumen))
				cast_on.visible_message(span_info("A choral sound comes from above and [cast_on] is healed!"), span_notice("I am bathed in healing choral hymns!"))
				do_healing(cast_on)
				return
	return TRUE

/datum/action/cooldown/spell/healing/proc/do_healing(mob/living/cast_on, conditional_buff = FALSE, situational_bonus = 0, wound_bonus = 0, situational_blood = 0, situational_energy = 0, situational_flags = NONE)
	var/amount_healed = base_healing
	var/wound_rate = wound_modifier
	var/blood_restored = blood_restoration
	var/energy_restored = energy_restoration
	var/heal_type = healing_flags

	var/datum/component/vampire_disguise/vampire_disguise = cast_on.GetComponent(/datum/component/vampire_disguise)

	if(conditional_buff)
		to_chat(owner, span_greentext("Channeling my patron's power is easier in these conditions!"))
		amount_healed += situational_bonus
		wound_rate += wound_bonus
		blood_restored += situational_blood
		energy_restored += situational_energy
		heal_type |= situational_flags

	if(vampire_disguise?.disguised) //vamps can pretend to be normal for a little bit
		var/vitae_loss = amount_healed * (cast_on.mind?.has_antag_datum(/datum/antagonist/vampire/lord) ? 0.3 : 0.6)
		cast_on.adjust_bloodpool(-vitae_loss)
		if(cast_on.bloodpool)
			to_chat(cast_on, span_danger("My disguise holds at the cost of [round(vitae_loss)] vitae!"))
		else
			vampire_disguise.force_undisguise(cast_on)
		return

	SEND_SIGNAL(owner, COMSIG_LIVING_HEALED_OTHER, amount_healed)
	if(heal_type &= MIRACLE_HEAL_TOX)
		cast_on.adjustToxLoss(-amount_healed)
	if(heal_type &= MIRACLE_HEAL_OXY)
		cast_on.adjustOxyLoss(-amount_healed)
	if(blood_restored)
		cast_on.blood_volume = max(cast_on.blood_volume, min(cast_on.blood_volume + blood_restored, BLOOD_VOLUME_NORMAL))
	if(energy_restored)
		cast_on.adjust_energy(energy_restored)
	if(!iscarbon(cast_on))
		cast_on.adjustBruteLoss(-amount_healed)
		cast_on.adjustFireLoss(-amount_healed)
		return

	var/mob/living/carbon/C = cast_on
	if(heal_type &= MIRACLE_HEAL_TARGET_ZONE)
		var/obj/item/bodypart/affecting = C.get_bodypart(check_zone(owner.zone_selected))
		if(affecting)
			affecting.heal_damage(amount_healed, amount_healed)
			affecting.heal_wounds(amount_healed * wound_rate)
			C.update_damage_overlays()
	else
		amount_healed /= max(1, length(C.bodyparts))
		for(var/obj/item/bodypart/B as anything in C.bodyparts)
			B.heal_damage(amount_healed, amount_healed)
			B.heal_wounds(amount_healed * wound_rate)
		C.update_damage_overlays()

/datum/action/cooldown/spell/healing/psydon
	name = "Enduring Spirit"
	healing_flags = MIRACLE_HEAL_TOX|MIRACLE_HEAL_OXY
	wound_modifier = 0.35

/datum/action/cooldown/spell/healing/psydon/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A strange stirring feeling pours from [cast_on]!"), span_notice("Sentimental thoughts drive away my pains!"))
		do_healing(cast_on)

/datum/action/cooldown/spell/healing/astrata
	name = "Healing Radiance"
	healing_flags = MIRACLE_HEAL_TOX|MIRACLE_HEAL_OXY
	base_healing = 15

/datum/action/cooldown/spell/healing/astrata/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A wreath of gentle light passes over [cast_on]!"), span_notice("I'm bathed in holy light!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 20
		// heal more based on time of day
		if(GLOB.tod != "night")
			if(GLOB.tod == "dawn" || "dusk")
				situational_bonus = 10
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/noc
	name = "Soothing Moonlight"
	healing_flags = MIRACLE_HEAL_TOX|MIRACLE_HEAL_OXY
	base_healing = 15

/datum/action/cooldown/spell/healing/noc/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A shroud of soft moonlight falls upon [cast_on]!"), span_notice("I'm shrouded in gentle moonlight!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		// heals more at night and a bit more if the target is sleeping
		if(GLOB.tod == "night")
			conditional_buff = TRUE
			situational_bonus = 15
		if(cast_on.IsSleeping())
			conditional_buff = TRUE
			situational_bonus += 10
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/dendor
	name = "Nature's Favor"
	healing_flags = MIRACLE_HEAL_TARGET_ZONE
	base_healing = 5

/datum/action/cooldown/spell/healing/dendor/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A rush of primal energy spirals about [cast_on]!"), span_notice("I'm infused with primal energies!"))
		var/static/list/natural_stuff = typecacheof(list(/obj/structure/flora, /obj/structure/chair/bench/ancientlog))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		var/situational_energy = 0
		var/area/our_area = get_area(owner)
		// additional healing when outdoors and in wilderness
		if(istype(our_area, /area/outdoors))
			situational_bonus = 5
			if(istype(our_area, /area/outdoors/wilderness))
				situational_bonus = 10
		// the more natural stuff around US, the more we heal
		for(var/obj/O in oview(5, owner))
			if(is_type_in_typecache(O, natural_stuff))
				situational_bonus = min(situational_bonus + 0.5, 25)
				situational_energy = min(situational_energy + 2, 50)
		if(situational_bonus > 0)
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus, 0, 0, situational_energy)

/datum/action/cooldown/spell/healing/abyssor
	name = "Mending Depths"
	base_healing = 10

/datum/action/cooldown/spell/healing/abyssor/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A mist of salt-scented vapour settles on [cast_on]!"), span_notice("I'm invigorated by healing vapours!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		var/situational_blood = 0
		var/situational_flags = MIRACLE_HEAL_OXY
		// if caster and/or target is standing in water, heal more based on depth
		var/turf/target_turf = get_turf(cast_on)
		if(istype(target_turf, /turf/open/water))
			var/turf/open/water/W = target_turf
			situational_bonus = 5 * W.water_level
			situational_blood = 10 * W.water_level
		if(cast_on != owner)
			var/turf/our_turf =  get_turf(owner)
			if(istype(our_turf, /turf/open/water))
				var/turf/open/water/W = our_turf
				situational_bonus += 5 * W.water_level
				situational_blood += 10 * W.water_level
		if(situational_bonus > 0)
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus, 0, situational_blood, 0, situational_flags)

/datum/action/cooldown/spell/healing/ravox
	name = "Fighting Chance"
	base_healing = 5

/datum/action/cooldown/spell/healing/ravox/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("An air of righteous defiance rises near [cast_on]!"), span_notice("I'm filled with an urge to fight on!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		var/situational_energy = 0
		// if wounded, heal more for each wound the more blood lost
		var/list/target_wounds = cast_on.get_wounds()
		if(length(target_wounds))
			conditional_buff = TRUE
			situational_bonus = (BLOOD_VOLUME_NORMAL - cast_on.blood_volume) * (0.01 * length(target_wounds))
			situational_energy = 10 * length(target_wounds)
		do_healing(cast_on, conditional_buff, situational_bonus, 0, 0, situational_energy)

/datum/action/cooldown/spell/healing/necra
	name = "Veil's Respite"
	healing_flags = MIRACLE_HEAL_TOX|MIRACLE_HEAL_OXY
	base_healing = 5

/datum/action/cooldown/spell/healing/necra/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A sense of quiet respite radiates from [cast_on]!"), span_notice("I feel the Undermaiden's gaze turn from me for now!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		if(iscarbon(cast_on))
			var/mob/living/carbon/C = cast_on
			// if the cast_on is "close to death" (at or below 25% health) heal on an exponential curve
			if(C.health <= (C.maxHealth * 0.25))
				conditional_buff = TRUE
				var/health_percentage = C.health / C.maxHealth
				situational_bonus = max(C.maxHealth * (0.001 ** health_percentage), 1)
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/xylix
	name = "Healing Gambit"
	base_healing = 10

/datum/action/cooldown/spell/healing/xylix/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A fugue seems to manifest briefly across [cast_on]!"), span_notice("My wounds vanish as if they had never been there!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		var/situational_flags = NONE
		// half of the time, heal a little (or a lot) more - flip the coin
		if(prob(50))
			conditional_buff = TRUE
			situational_bonus = rand(1, 40)
			if(prob(50))
				situational_flags |= MIRACLE_HEAL_TOX
			if(prob(50))
				situational_flags |= MIRACLE_HEAL_OXY
		do_healing(cast_on, conditional_buff, situational_bonus, 0, 0, 0, situational_flags)

/datum/action/cooldown/spell/healing/pestra
	name = "Balance Humors"
	healing_flags = MIRACLE_HEAL_OXY|MIRACLE_HEAL_TARGET_ZONE
	base_healing = 10
	wound_modifier = 0.3

/datum/action/cooldown/spell/healing/pestra/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("An aura of clinical care encompasses [cast_on]!"), span_notice("I'm sewn back together by sacred medicine!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		var/wound_bonus = 0
		var/situational_blood = 0
		var/situational_flags = NONE
		// when above target blood volume, heal more while leeching some blood
		if(cast_on.blood_volume > BLOOD_VOLUME_OKAY)
			conditional_buff = TRUE
			situational_bonus = 20
			wound_bonus = 0.7
			cast_on.blood_volume = cast_on.blood_volume - (BLOOD_VOLUME_SURVIVE * 0.5)
			situational_flags |= MIRACLE_HEAL_TOX
		// when below target blood volume, restore blood
		else if(cast_on.blood_volume > BLOOD_VOLUME_BAD)
			situational_blood = BLOOD_VOLUME_SURVIVE * 0.25
		else if(cast_on.blood_volume > BLOOD_VOLUME_SURVIVE)
			situational_blood = BLOOD_VOLUME_SURVIVE * 0.5
		else
			situational_blood = BLOOD_VOLUME_SURVIVE
		do_healing(cast_on, conditional_buff, situational_bonus, wound_bonus, situational_blood, 0, situational_flags)

/datum/action/cooldown/spell/healing/malum
	name = "Forged Resilience"
	base_healing = 10

/datum/action/cooldown/spell/healing/malum/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A tempering heat is discharged out of [cast_on]!"), span_notice("I feel the heat of a forge soothing my pains!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		var/situational_energy = 0
		for(var/obj/machinery/light/fueled/O in oview(5, owner))
			if(!O.on)
				continue
			situational_bonus = min(situational_bonus + 3, 30)
			situational_energy = min(situational_energy + 20, max((cast_on.max_energy * 0.2) - cast_on.energy, 0))
		if(situational_bonus > 0)
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus, 0, 0, situational_energy)

/datum/action/cooldown/spell/healing/eora
	name = "Divine Embrace"
	base_healing = 15

/datum/action/cooldown/spell/healing/eora/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("An eminence of love blossoms around [cast_on]!"), span_notice("I'm filled with the restorative warmth of love!"))
		// if they're wearing an eoran bud (or are a pacifist), pretty much double the healing.
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		if(HAS_TRAIT(cast_on, TRAIT_PACIFISM))
			conditional_buff = TRUE
			situational_bonus = 25
		// additional healing if they've been hugged
		if(cast_on.has_stress_type(/datum/stress_event/hug))
			conditional_buff = TRUE
			situational_bonus += 10
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/profane
	name = "Corrupt Lesser Miracle"
	antimagic_flags = MAGIC_RESISTANCE_UNHOLY
	required_items = null
	healing_type = HEALING_PROFANE

/datum/action/cooldown/spell/healing/profane/zizo
	name = "Channel Vitality"
	base_healing = 15

/datum/action/cooldown/spell/healing/profane/zizo/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("Vital energies are sapped towards [cast_on]!"), span_notice("The life around me pales as I am restored!"))
		// consume bones in the surrounding area for healing and draw energy from fresh corpses, rotting them faster
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		for(var/obj/item/alch/bone/O in oview(5, owner))
			if(situational_bonus < 50)
				situational_bonus += 5
				qdel(O)
		for(var/mob/living/carbon/C in oview(1, owner))
			if(C == cast_on || C.stat != DEAD)
				continue
			var/datum/component/rot/corpse/R = C.GetComponent(/datum/component/rot/corpse)
			if(!R)
				continue
			for(var/obj/item/bodypart/B as anything in C.bodyparts)
				if(B.skeletonized || B.rotted)
					continue
				if(B.is_organic_limb())
					R.amount += 2.5 MINUTES
					situational_bonus += 5
		if(situational_bonus > 0)
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/profane/graggar
	name = "Putrid Poultice"
	healing_flags = MIRACLE_HEAL_TARGET_ZONE
	base_healing = 10
	wound_modifier = 0.3

/datum/action/cooldown/spell/healing/profane/graggar/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("Foul fumes billow outward as [cast_on] is restored!"), span_notice("A noxious scent burns my nostrils, but I feel better!"))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		// lingering toxin damage in caster or target boosts healing, tainting unafflicted targets
		var/target_toxloss = cast_on.getToxLoss()
		if(target_toxloss >= 10)
			situational_bonus = 25
		if(cast_on != owner && isliving(owner))
			var/mob/living/living_owner = owner
			if(living_owner.getToxLoss() >= 10)
				situational_bonus += 25
				if(target_toxloss < 10)
					cast_on.setToxLoss(10)
		if(situational_bonus > 0)
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/profane/matthios
	name = "Outlaw's Draught"
	base_healing = 10

/datum/action/cooldown/spell/healing/profane/matthios/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A shadowed hand passes [cast_on] a small, stolen vial... its contents glimmer faintly before sinking into their veins..."), span_notice("A quick swig and the ache fades..."))
		var/conditional_buff = FALSE
		var/situational_bonus = 25
		var/situational_blood = BLOOD_VOLUME_SURVIVE * 0.5
		// COMRADES! WE MUST BAND TOGETHER! Or Outlaw.
		if(HAS_TRAIT(cast_on, TRAIT_BANDITCAMP) || (cast_on.real_name in GLOB.outlawed_players))
			conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus, 0, situational_blood)

/datum/action/cooldown/spell/healing/profane/baotha
	name = "Intoxicating Aid"
	base_healing = 15

/datum/action/cooldown/spell/healing/profane/baotha/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("A sweet, dizzying haze swirls around [cast_on], their eyes glimmering with bliss..."), span_notice("Mmm... the world softens... and I melt into it..."))
		var/conditional_buff = FALSE
		var/situational_bonus = 0
		//If the owner or cast_on are on drugs or drunk, they get a heal bonus.
		var/static/list/drugs_buffs = list(
			/datum/status_effect/buff/druqks,
			/datum/status_effect/buff/ozium,
			/datum/status_effect/buff/moondust,
			/datum/status_effect/buff/weed,
			/datum/status_effect/buff/moondust_purest,
		)

		if(isliving(owner))
			var/mob/living/living_owner = owner
			for(var/datum/status_effect/path as anything in drugs_buffs)
				if(living_owner.has_status_effect(path) || cast_on.has_status_effect(path))
					situational_bonus = 25
					break
			if(living_owner.has_status_effect(/datum/status_effect/buff/drunk) || cast_on.has_status_effect(/datum/status_effect/buff/drunk))
				situational_bonus += 25
			if(situational_bonus > 0)
				conditional_buff = TRUE
		do_healing(cast_on, conditional_buff, situational_bonus)

/datum/action/cooldown/spell/healing/hunt
	name = "Hunter's Will"
	required_items = list(/obj/item/clothing/neck/psycross/great_hunt)
	healing_type = HEALING_HUNT

	base_healing = 35
	wound_modifier = 0.35

/datum/action/cooldown/spell/healing/hunt/cast(mob/living/cast_on)
	. = ..()
	if(.)
		cast_on.visible_message(span_info("The smell of wet grass and earth surrounds [cast_on]!"), span_notice("I'm surrounded by the smell of wet grass and earth!"))
		// The more alchemically significant body parts around the caster, the greater the effect.
		var/conditional_buff = FALSE
		var/situational_bonus = min(check_hunt_bonuses(owner, 5, 50, 0.5), 25)
		var/situational_blood = 0
		if(situational_bonus > 0)
			conditional_buff = TRUE

		//Holding the head of an animal can restore blood.
		var/obj/item/natural/head/animal_head = owner.get_active_held_item()
		if(animal_head)
			if(!animal_head.blood_value)
				to_chat(owner, span_warning("This head is not valuable enough to aid in healing!"))
			else
				situational_blood = animal_head.blood_value
				consume_hunt_bonus(animal_head)
		do_healing(cast_on, conditional_buff, situational_bonus, 0, situational_blood)

/datum/action/cooldown/spell/healing/greater
	name = "Miracle"
	button_icon_state = "astrata"

	charge_required = TRUE
	charge_time = 1 SECONDS
	cooldown_time = 20 SECONDS
	spell_cost = 45

	healing_flags = MIRACLE_HEAL_TOX|MIRACLE_HEAL_OXY
	base_healing = 50
	wound_modifier = 0.5
	blood_restoration = BLOOD_VOLUME_SURVIVE
	stun_undead = TRUE
	patron_restrictive = TRUE

/datum/action/cooldown/spell/healing/greater/profane
	name = "Corrupt Miracle"
	antimagic_flags = MAGIC_RESISTANCE_UNHOLY
	required_items = null
	stun_undead = FALSE
	healing_type = HEALING_PROFANE


#undef MIRACLE_HEAL_TOX
#undef MIRACLE_HEAL_OXY
#undef MIRACLE_HEAL_TARGET_ZONE
#undef HEALING_DIVINE
#undef HEALING_PROFANE
#undef HEALING_HUNT

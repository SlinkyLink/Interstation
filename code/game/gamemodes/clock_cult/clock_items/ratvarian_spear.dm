//Ratvarian spear: A relatively fragile spear from the Celestial Derelict. Deals extreme damage to silicons and enemy cultists, but doesn't last long when summoned.
/obj/item/clockwork/ratvarian_spear
	name = "ratvarian spear"
	desc = "A razor-sharp spear made of brass. It thrums with barely-contained energy."
	clockwork_desc = "A fragile spear of Ratvarian making. It's more effective against enemy cultists and silicons, though it won't last long."
	icon = 'icons/obj/clockwork_objects.dmi'
	icon_state = "ratvarian_spear"
	item_state = "ratvarian_spear"
	force = 17 //Extra damage is dealt to silicons in attack()
	throwforce = 40
	sharpness = IS_SHARP_ACCURATE
	attack_verb = list("stabbed", "poked", "slashed")
	hitsound = 'sound/weapons/bladeslice.ogg'
	w_class = 4
	var/impale_cooldown = 50 //delay, in deciseconds, where you can't impale again
	var/attack_cooldown = 10 //delay, in deciseconds, where you can't attack with the spear

/obj/item/clockwork/ratvarian_spear/New()
	..()
	impale_cooldown = 0
	update_force()

/obj/item/clockwork/ratvarian_spear/proc/update_force()
	if(ratvar_awakens) //If Ratvar is alive, the spear is extremely powerful
		force = 30
		throwforce = 50
	else
		force = initial(force)
		throwforce = initial(throwforce)

/obj/item/clockwork/ratvarian_spear/examine(mob/user)
	..()
	if(is_servant_of_ratvar(user) || isobserver(user))
		user << "<span class='brass'>Stabbing a human you are pulling or have grabbed with the spear will impale them, doing massive damage and stunning.</span>"
		user << "<span class='brass'>Throwing the spear will do massive damage, break the spear, and stun the target.</span>"

/obj/item/clockwork/ratvarian_spear/attack(mob/living/target, mob/living/carbon/human/user)
	var/impaling = FALSE
	if(attack_cooldown > world.time)
		user << "<span class='warning'>You can't attack right now, wait [max(round((attack_cooldown - world.time)*0.1, 0.1), 0)] seconds!</span>"
		return
	if(user.pulling && ishuman(user.pulling) && user.pulling == target)
		if(impale_cooldown > world.time)
			user << "<span class='warning'>You can't impale [target] yet, wait [max(round((impale_cooldown - world.time)*0.1, 0.1), 0)] seconds!</span>"
		else
			impaling = TRUE
			attack_verb = list("impaled")
			force += 23 //40 damage if ratvar isn't alive, 53 if he is
			user.stop_pulling()

	if(impaling)
		if(hitsound)
			playsound(loc, hitsound, get_clamped_volume(), 1, -1)
		user.lastattacked = target
		target.lastattacker = user
		if(!target.attacked_by(src, user))
			impaling = FALSE //if we got blocked, stop impaling
		add_logs(user, target, "attacked", src.name, "(INTENT: [uppertext(user.a_intent)]) (DAMTYPE: [uppertext(damtype)])")
		add_fingerprint(user)
	else //todo yell at someone to make attack() use proper return values
		..()

	if(issilicon(target))
		var/mob/living/silicon/S = target
		if(S.stat != DEAD)
			S.visible_message("<span class='warning'>[S] shudders violently at [src]'s touch!</span>", "<span class='userdanger'>ERROR: Temperature rising!</span>")
			S.adjustFireLoss(25)
	else if(iscultist(target) || isconstruct(target)) //Cultists take extra fire damage
		var/mob/living/M = target
		if(M.stat != DEAD)
			M << "<span class='userdanger'>Your body flares with agony at [src]'s presence!</span>"
			M.adjustFireLoss(10)
	attack_verb = list("stabbed", "poked", "slashed")
	update_force()
	if(impaling)
		impale_cooldown = world.time + initial(impale_cooldown)
		attack_cooldown = world.time + initial(attack_cooldown)
		if(target)
			PoolOrNew(/obj/effect/overlay/temp/dir_setting/bloodsplatter, list(get_turf(target), get_dir(user, target)))
			target.Stun(2)
			user << "<span class='brass'>You prepare to remove your ratvarian spear from [target]...</span>"
			var/remove_verb = pick("pull", "yank", "drag")
			if(do_after(user, 10, 1, target))
				var/turf/T = get_turf(target)
				var/obj/effect/overlay/temp/dir_setting/bloodsplatter/B = PoolOrNew(/obj/effect/overlay/temp/dir_setting/bloodsplatter, list(T, get_dir(target, user)))
				playsound(T, 'sound/misc/splort.ogg', 200, 1)
				playsound(T, 'sound/weapons/pierce.ogg', 200, 1)
				if(target.stat != CONSCIOUS)
					user.visible_message("<span class='warning'>[user] [remove_verb]s [src] out of [target]!</span>", "<span class='warning'>You [remove_verb] your spear from [target]!</span>")
				else
					user.visible_message("<span class='warning'>[user] kicks [target] off of [src]!</span>", "<span class='warning'>You kick [target] off of [src]!</span>")
					target << "<span class='userdanger'>You scream in pain as you're kicked off of [src]!</span>"
					target.emote("scream")
					step(target, get_dir(user, target))
					T = get_turf(target)
					B.forceMove(T)
					target.Weaken(2)
					playsound(T, 'sound/weapons/thudswoosh.ogg', 50, 1)
				flash_color(target, flash_color="#911414", flash_time=8)
			else if(target) //it's a do_after, we gotta check again to make sure they didn't get deleted
				user.visible_message("<span class='warning'>[user] [remove_verb]s [src] out of [target]!</span>", "<span class='warning'>You [remove_verb] your spear from [target]!</span>")
				if(target.stat == CONSCIOUS)
					target << "<span class='userdanger'>You scream in pain as [src] is suddenly [remove_verb]ed out of you!</span>"
					target.emote("scream")
				flash_color(target, flash_color="#911414", flash_time=4)

/obj/item/clockwork/ratvarian_spear/throw_impact(atom/target)
	var/turf/T = get_turf(target)
	if(..() || !isliving(target))
		return
	var/mob/living/L = target
	if(issilicon(L) || iscultist(L))
		L.Stun(6)
		L.Weaken(6)
	else
		L.Stun(2)
		L.Weaken(2)
	break_spear(T)

/obj/item/clockwork/ratvarian_spear/proc/break_spear(turf/T)
	if(src)
		if(!T)
			T = get_turf(src)
		if(T) //make sure we're not in null or something
			T.visible_message("<span class='warning'>[src] [pick("cracks in two and fades away", "snaps in two and dematerializes")]!</span>")
			PoolOrNew(/obj/effect/overlay/temp/ratvar/spearbreak, T)
		qdel(src)

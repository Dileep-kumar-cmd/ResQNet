class FirstAidProtocol {
  final String id;
  final String title;
  final String category; // INJURIES, BURNS, BREATHING, CARDIAC, NEUROLOGICAL, BONE_MUSCLE, BITES_STINGS, ENVIRONMENTAL, POISONING
  final String urgency; // CRITICAL, HIGH, MEDIUM
  final String overview;
  final List<String> steps;
  final List<String> warnings;
  final List<String> whatNotToDo;
  final String equipmentNeeded;

  FirstAidProtocol({
    required this.id,
    required this.title,
    required this.category,
    required this.urgency,
    required this.overview,
    required this.steps,
    required this.warnings,
    required this.whatNotToDo,
    required this.equipmentNeeded,
  });
}

class FirstAidData {
  static final List<FirstAidProtocol> protocols = [
    // --- INJURIES ---
    FirstAidProtocol(
      id: 'inj_01',
      title: 'Severe Bleeding & Hemorrhage Control',
      category: 'INJURIES',
      urgency: 'CRITICAL',
      overview: 'Rapid control of arterial or venous bleeding to prevent hemorrhagic shock.',
      equipmentNeeded: 'Sterile gauze, pressure bandage, commercial Tourniquet',
      warnings: [
        'Do not remove blood-soaked dressings; add more layers on top.',
        'Apply tourniquet 2-3 inches above wound on limb if direct pressure fails.'
      ],
      whatNotToDo: [
        'Do not remove embedded objects from deep wounds.',
        'Do not loosen tourniquet once applied.'
      ],
      steps: [
        'Apply firm, direct pressure over the bleeding wound using sterile cloth or gloved hand.',
        'Elevate injured limb above heart level if no bone fracture is suspected.',
        'Wrap tightly with pressure bandage.',
        'If bleeding continues from an arm or leg, apply a commercial tourniquet high and tight.',
        'Tighten windlass until arterial bleeding stops completely and mark time on victim\'s forehead (T=HH:MM).'
      ],
    ),
    FirstAidProtocol(
      id: 'inj_02',
      title: 'Minor Cuts & Lacerations',
      category: 'INJURIES',
      urgency: 'MEDIUM',
      overview: 'Cleaning and dressing superficial wounds to prevent infection.',
      equipmentNeeded: 'Clean water, mild soap, adhesive bandage, antiseptic wipe',
      warnings: ['Watch for signs of infection (redness, pus, fever) over next 24-48 hours.'],
      whatNotToDo: ['Do not scrub deep cuts harshly.', 'Do not use hydrogen peroxide on open wounds.'],
      steps: [
        'Wash hands with soap and water before touching wound.',
        'Rinse wound thoroughly under clean running water for 5 minutes.',
        'Apply mild pressure with sterile cloth to stop minor bleeding.',
        'Apply thin layer of antibiotic ointment if available.',
        'Cover wound with a sterile adhesive bandage or gauze dressing.'
      ],
    ),
    FirstAidProtocol(
      id: 'inj_03',
      title: 'Deep Wounds & Puncture Wounds',
      category: 'INJURIES',
      urgency: 'HIGH',
      overview: 'First aid for deep cuts caused by sharp objects or rusty nails.',
      equipmentNeeded: 'Sterile gauze, sterile bandage, clean water',
      warnings: ['High risk of tetanus infection. Tetanus booster recommended within 48 hours.'],
      whatNotToDo: ['Do not pull out deeply embedded impaled objects.', 'Do not probe inside wound.'],
      steps: [
        'Stabilize any impaled object with bulky dressings around it.',
        'Control peripheral bleeding with direct pressure around object.',
        'Rinse outer area with clean water without disturbing deep tissue.',
        'Cover loosely with sterile bandage.',
        'Seek immediate professional medical care for deep tetanus evaluation.'
      ],
    ),
    FirstAidProtocol(
      id: 'inj_04',
      title: 'Nosebleeds (Epistaxis)',
      category: 'INJURIES',
      urgency: 'MEDIUM',
      overview: 'Care for anterior and posterior nasal bleeding.',
      equipmentNeeded: 'Tissues or clean cloth, cold compress',
      warnings: ['If nosebleed persists past 20 minutes of continuous pressure, seek emergency care.'],
      whatNotToDo: ['Do NOT tilt head backward (can cause blood inhalation or vomiting).', 'Do not pack nose with gauze.'],
      steps: [
        'Sit upright and lean head slightly FORWARD.',
        'Pinch soft part of nose just below bridge firmly between thumb and index finger.',
        'Hold continuous pressure for 10-15 minutes without releasing to check.',
        'Apply cold compress to bridge of nose or back of neck.',
        'Breathe gently through mouth until bleeding stops.'
      ],
    ),

    // --- BURNS ---
    FirstAidProtocol(
      id: 'burn_01',
      title: 'Thermal Burns (Minor & Severe)',
      category: 'BURNS',
      urgency: 'HIGH',
      overview: 'First-aid care for flame, hot liquid, or steam contact burns.',
      equipmentNeeded: 'Cool clean water, sterile non-adherent dressing, clean blanket',
      warnings: [
        'Cool thermal burn immediately with cool running water for 10-20 minutes.',
        'Cover loosely with sterile non-adherent gauze.'
      ],
      whatNotToDo: [
        'Never apply ice directly to burns.',
        'Never apply butter, oil, grease, or toothpastes.',
        'Do not pop burn blisters.'
      ],
      steps: [
        'Remove victim from heat source safely.',
        'Cool burned area under cool running water for 10-20 minutes (do not use ice).',
        'Remove jewelry or restrictive clothing before swelling starts.',
        'Cover burn loosely with sterile non-stick bandage or clean wrap.',
        'Keep victim warm with clean blanket to prevent hypothermia.'
      ],
    ),
    FirstAidProtocol(
      id: 'burn_02',
      title: 'Chemical Burns',
      category: 'BURNS',
      urgency: 'CRITICAL',
      overview: 'Emergency flushing for skin or eye exposure to corrosive chemicals.',
      equipmentNeeded: 'Copious running water, eye wash bottle, protective gloves',
      warnings: ['Flush eyes continuously if chemical contact occurred.'],
      whatNotToDo: ['Do not attempt to neutralize chemical with acids/alkalis (causes thermal reaction).'],
      steps: [
        'Ensure responder safety; wear protective gloves.',
        'Brush dry chemical powders off skin before flushing.',
        'Flush affected area immediately with large amounts of running water for at least 20 minutes.',
        'Remove contaminated clothing while flushing.',
        'Cover loosely with clean dressing and seek emergency medical care.'
      ],
    ),
    FirstAidProtocol(
      id: 'burn_03',
      title: 'Electrical Burns & Shock',
      category: 'BURNS',
      urgency: 'CRITICAL',
      overview: 'Safety protocol for high/low voltage electrical injuries.',
      equipmentNeeded: 'Non-conductive wooden stick, sterile dressings, CPR barrier',
      warnings: ['Do not touch victim until power source is confirmed disconnected.'],
      whatNotToDo: ['Do not touch live electrical wires or victim in contact with live wire.'],
      steps: [
        'Shut off power main or remove wire with dry non-conductive object (wood/plastic).',
        'Check victim\'s responsiveness and breathing once safe.',
        'Begin CPR immediately if victim is non-responsive and not breathing.',
        'Treat entrance and exit burn sites with dry sterile dressings.',
        'Keep victim still and treat for shock.'
      ],
    ),

    // --- BREATHING EMERGENCIES ---
    FirstAidProtocol(
      id: 'br_01',
      title: 'Choking Relief (Heimlich Maneuver)',
      category: 'BREATHING',
      urgency: 'CRITICAL',
      overview: 'Abdominal thrusts for airway obstruction in conscious adult/child.',
      equipmentNeeded: 'None',
      warnings: ['If victim becomes unconscious, lower to ground and begin CPR compressions.'],
      whatNotToDo: ['Do not perform finger sweep unless object is clearly visible in mouth.'],
      steps: [
        'Ask victim "Are you choking?". If they cannot talk or cough, act immediately.',
        'Stand behind victim and wrap arms around their waist.',
        'Make a fist with one hand and place thumb side just above navel.',
        'Grasp fist with other hand and deliver quick, upward abdominal thrusts.',
        'Repeat thrusts until object is expelled or victim loses consciousness.'
      ],
    ),
    FirstAidProtocol(
      id: 'br_02',
      title: 'Asthma Attack & Respiratory Distress',
      category: 'BREATHING',
      urgency: 'HIGH',
      overview: 'Assisting a person suffering acute bronchospasm.',
      equipmentNeeded: 'Rescue Inhaler (Albuterol), Spacer device',
      warnings: ['If lips turn blue or victim cannot speak, call emergency services immediately.'],
      whatNotToDo: ['Do not force victim to lie down flat.'],
      steps: [
        'Help victim sit upright in a comfortable position leaning slightly forward.',
        'Assist victim in taking 1-2 puffs of their rescue inhaler.',
        'Use spacer device if available.',
        'Encourage slow, deep diaphragmatic breathing.',
        'Repeat inhaler dose after 4 minutes if no improvement.'
      ],
    ),
    FirstAidProtocol(
      id: 'br_03',
      title: 'Smoke Inhalation & Toxic Gas Exposure',
      category: 'BREATHING',
      urgency: 'CRITICAL',
      overview: 'Care for victims exposed to fire smoke or hazardous fumes.',
      equipmentNeeded: 'Oxygen if available, wet cloth mask',
      warnings: ['Rescuer must not enter confined toxic environment without respiratory gear.'],
      whatNotToDo: ['Do not stay in smoke-filled room.'],
      steps: [
        'Move victim immediately to fresh air environment.',
        'Loosen tight clothing around neck and chest.',
        'Monitor airway, breathing, and circulation.',
        'Administer oxygen if trained responder and equipment available.',
        'Keep victim calm and seek urgent hospital evaluation.'
      ],
    ),

    // --- CARDIAC EMERGENCIES ---
    FirstAidProtocol(
      id: 'card_01',
      title: 'Adult Cardiopulmonary Resuscitation (CPR)',
      category: 'CARDIAC',
      urgency: 'CRITICAL',
      overview: 'High-quality chest compressions for cardiac arrest victims.',
      equipmentNeeded: 'Automated External Defibrillator (AED), CPR barrier mask',
      warnings: [
        'Deliver compressions 2 to 2.4 inches deep at 100-120 compressions per minute.',
        'Apply AED as soon as available.'
      ],
      whatNotToDo: ['Do not stop compressions for more than 10 seconds.'],
      steps: [
        'Verify scene safety. Check victim responsiveness.',
        'Shout for help and call emergency services / request AED.',
        'Place heel of hand on center of chest (lower half of sternum).',
        'Push hard and fast 30 times (100-120 bpm), allowing full chest recoil.',
        'Give 2 gentle rescue breaths (1 sec each). Repeat 30:2 ratio until AED or paramedics arrive.'
      ],
    ),
    FirstAidProtocol(
      id: 'card_02',
      title: 'Chest Pain & Suspected Heart Attack',
      category: 'CARDIAC',
      urgency: 'CRITICAL',
      overview: 'Emergency management of acute coronary syndrome signs.',
      equipmentNeeded: 'Aspirin (325mg chewable), Nitroglycerin if prescribed',
      warnings: ['Do not give aspirin if victim has severe aspirin allergy or bleeding disorder.'],
      whatNotToDo: ['Do not let victim walk or exert themselves.'],
      steps: [
        'Call emergency medical services immediately.',
        'Have victim sit down, rest, and remain calm in semi-seated position.',
        'Chew and swallow one adult aspirin (325mg) if not allergic.',
        'Assist with prescribed nitroglycerin tablet under tongue if available.',
        'Monitor breathing and be prepared to start CPR if victim loses consciousness.'
      ],
    ),
    FirstAidProtocol(
      id: 'card_03',
      title: 'Fainting & Syncope',
      category: 'CARDIAC',
      urgency: 'MEDIUM',
      overview: 'First aid for temporary loss of consciousness due to reduced brain blood flow.',
      equipmentNeeded: 'Cool damp cloth',
      warnings: ['If victim does not regain consciousness within 1 minute, treat as medical emergency.'],
      whatNotToDo: ['Do not stand victim up prematurely.'],
      steps: [
        'Lay victim flat on back on floor.',
        'Elevate legs 12 inches (30 cm) above heart level.',
        'Loosen restrictive belts, collars, and tight clothing.',
        'Apply cool damp cloth to forehead.',
        'Allow victim to recover gradually before sitting up.'
      ],
    ),

    // --- NEUROLOGICAL EMERGENCIES ---
    FirstAidProtocol(
      id: 'neuro_01',
      title: 'Stroke Recognition & FAST Action',
      category: 'NEUROLOGICAL',
      urgency: 'CRITICAL',
      overview: 'Rapid identification of cerebral vascular accident.',
      equipmentNeeded: 'Time clock',
      warnings: ['Time is critical for thrombolytic clot-busting medication.'],
      whatNotToDo: ['Do not give victim food, water, or medication.'],
      steps: [
        'F - Face Drooping: Ask person to smile. Does one side droop?',
        'A - Arm Weakness: Ask person to raise both arms. Does one arm drift downward?',
        'S - Speech Difficulty: Ask person to repeat simple sentence. Is speech slurred?',
        'T - Time to Call Emergency: Note exact onset time of symptoms and call EMS immediately.',
        'Keep victim lying on side if vomiting or unconscious.'
      ],
    ),
    FirstAidProtocol(
      id: 'neuro_02',
      title: 'Seizures & Epilepsy First Aid',
      category: 'NEUROLOGICAL',
      urgency: 'HIGH',
      overview: 'Protection protocol during tonic-clonic convulsions.',
      equipmentNeeded: 'Soft pillow or folded jacket',
      warnings: ['Time duration of seizure. If > 5 mins, call emergency medical response.'],
      whatNotToDo: [
        'NEVER put objects or fingers in victim\'s mouth.',
        'Do not restrain victim\'s movements.'
      ],
      steps: [
        'Ease victim to floor and clear area of hard/sharp objects.',
        'Place soft padding under victim\'s head.',
        'Turn victim gently onto side (recovery position) to clear airway.',
        'Stay with victim until seizure ends and full consciousness returns.',
        'Reassure victim as they recover.'
      ],
    ),
    FirstAidProtocol(
      id: 'neuro_03',
      title: 'Head Injury & Concussion',
      category: 'NEUROLOGICAL',
      urgency: 'HIGH',
      overview: 'Care for blunt force head trauma and brain injury.',
      equipmentNeeded: 'Ice pack wrapped in cloth, sterile bandage',
      warnings: ['Watch for vomiting, unequal pupils, worsening confusion, or clear fluid from nose/ears.'],
      whatNotToDo: ['Do not move neck if spinal trauma suspected.'],
      steps: [
        'Keep victim still with head and shoulders slightly elevated.',
        'Control scalp bleeding with gentle direct pressure (unless skull fracture suspected).',
        'Apply cold pack wrapped in cloth to reduce swelling.',
        'Monitor level of consciousness continuously.',
        'Seek immediate medical evaluation for all loss-of-consciousness incidents.'
      ],
    ),

    // --- BONE AND MUSCLE INJURIES ---
    FirstAidProtocol(
      id: 'bone_01',
      title: 'Bone Fracture & Limb Splinting',
      category: 'BONE_MUSCLE',
      urgency: 'HIGH',
      overview: 'Immobilization of fractured bones to prevent secondary tissue damage.',
      equipmentNeeded: 'Rigid board or SAM splint, cloth strips, padding',
      warnings: [
        'Do not attempt to force bone back into place.',
        'Check circulation (pulse and capillary refill) below splint before and after application.'
      ],
      whatNotToDo: ['Do not move limb unnecessarily.'],
      steps: [
        'Support injured area manually above and below fracture site.',
        'Check circulation, sensation, and movement (CSM) distal to injury.',
        'Apply padded rigid splint extending past joints above and below fracture.',
        'Secure splint firmly with cloth ties without cutting off blood circulation.',
        'Re-verify circulation below splint every 15 minutes.'
      ],
    ),
    FirstAidProtocol(
      id: 'bone_02',
      title: 'Sprains & Strains (R.I.C.E. Protocol)',
      category: 'BONE_MUSCLE',
      urgency: 'MEDIUM',
      overview: 'First aid for ligament sprains and tendon strains.',
      equipmentNeeded: 'Elastic bandage (Ace wrap), Ice pack',
      warnings: ['Seek X-ray evaluation if unable to bear weight.'],
      whatNotToDo: ['Do not apply direct heat during first 48 hours.'],
      steps: [
        'R - Rest: Stop activity and protect injured joint.',
        'I - Ice: Apply ice pack wrapped in towel for 15-20 mins every 2 hours.',
        'C - Compression: Wrap lightly with elastic bandage starting below injury.',
        'E - Elevation: Elevate injured limb above level of heart.',
        'Avoid weight bearing until evaluated.'
      ],
    ),
    FirstAidProtocol(
      id: 'bone_03',
      title: 'Suspected Spinal Cord Injury Care',
      category: 'BONE_MUSCLE',
      urgency: 'CRITICAL',
      overview: 'Strict spinal immobilization for trauma victims.',
      equipmentNeeded: 'Cervical collar or rolled towels/sandbags',
      warnings: ['IMPROPER MOVEMENT CAN CAUSE PERMANENT PARALYSIS OR DEATH.'],
      whatNotToDo: ['Do NOT move victim unless in immediate life-threatening danger.'],
      steps: [
        'Keep victim in exact position found.',
        'Hold victim\'s head firmly with both hands to prevent any head/neck rotation.',
        'Place heavy rolled towels or sandbags on both sides of head.',
        'If log-roll required due to vomiting, roll head, neck, and torso as a single rigid unit.',
        'Wait for trained search & rescue team with spine board.'
      ],
    ),

    // --- BITES AND STINGS ---
    FirstAidProtocol(
      id: 'bite_01',
      title: 'Venomous Snake Bite Protocol',
      category: 'BITES_STINGS',
      urgency: 'CRITICAL',
      overview: 'Immediate management of pit viper or elapid snake envenomation.',
      equipmentNeeded: 'Clean cloth, pressure immobilization bandage',
      warnings: ['Keep bitten limb immobilized BELOW heart level.'],
      whatNotToDo: [
        'NEVER cut wound or attempt to suck out venom.',
        'Do NOT apply tourniquet or ice to snake bites.'
      ],
      steps: [
        'Move victim safely away from snake range. Keep victim calm and motionless.',
        'Remove rings, watches, and tight clothing before swelling begins.',
        'Wash bite area gently with soap and water.',
        'Apply broad pressure bandage over bite site and wrap entire limb snugly.',
        'Immobilize limb with splint and transport immediately to hospital for antivenom.'
      ],
    ),
    FirstAidProtocol(
      id: 'bite_02',
      title: 'Animal & Dog Bites (Rabies Hazard)',
      category: 'BITES_STINGS',
      urgency: 'HIGH',
      overview: 'Wound care and infection/rabies prevention.',
      equipmentNeeded: 'Running water, soap, sterile bandage',
      warnings: ['High infection and rabies risk. Medical evaluation mandatory.'],
      whatNotToDo: ['Do not close deep bite puncture wounds tightly without medical irrigation.'],
      steps: [
        'Flush wound thoroughly under running water with soap for at least 15 minutes.',
        'Apply pressure with clean cloth to control bleeding.',
        'Apply antibiotic ointment and cover with sterile bandage.',
        'Report animal bite to local health/rescue authorities.',
        'Seek medical facility for rabies post-exposure prophylaxis.'
      ],
    ),
    FirstAidProtocol(
      id: 'bite_03',
      title: 'Insect Stings & Anaphylaxis',
      category: 'BITES_STINGS',
      urgency: 'CRITICAL',
      overview: 'Treatment for bee/wasp stings and severe allergic reaction.',
      equipmentNeeded: 'Card edge, Ice pack, Epinephrine Auto-Injector (EpiPen)',
      warnings: ['If throat swelling, hives, or breathing difficulty occurs, administer EpiPen immediately.'],
      whatNotToDo: ['Do not squeeze sting venom sac with tweezers.'],
      steps: [
        'Scrape off stinger gently with edge of plastic credit card (do not squeeze).',
        'Wash area with soap and water.',
        'Apply cold pack to reduce localized swelling.',
        'If victim shows signs of anaphylaxis (difficulty breathing, facial swelling):',
        'Press EpiPen firmly into outer mid-thigh at 90° angle for 3 seconds, then call EMS.'
      ],
    ),

    // --- ENVIRONMENTAL EMERGENCIES ---
    FirstAidProtocol(
      id: 'env_01',
      title: 'Heat Stroke (Life-Threatening Hyperthermia)',
      category: 'ENVIRONMENTAL',
      urgency: 'CRITICAL',
      overview: 'Emergency rapid cooling for body core temp > 104°F (40°C).',
      equipmentNeeded: 'Cold water tub, ice packs, wet sheets, fan',
      warnings: ['Heat stroke is a medical emergency that can cause organ failure.'],
      whatNotToDo: ['Do not give fluids if victim is confused or unconscious.'],
      steps: [
        'Move victim immediately to shade or air-conditioned space.',
        'Call emergency medical services right away.',
        'Immerse victim in cold water tub if available (cold water immersion).',
        'Alternatively, douse skin with cool water, wrap in wet sheets, and fan vigorously.',
        'Place ice packs on neck, armpits, and groin.'
      ],
    ),
    FirstAidProtocol(
      id: 'env_02',
      title: 'Heat Exhaustion & Dehydration',
      category: 'ENVIRONMENTAL',
      urgency: 'MEDIUM',
      overview: 'Care for heavy sweating, dizziness, and electrolyte depletion.',
      equipmentNeeded: 'Oral Rehydration Solution (ORS), electrolyte drink, cool water',
      warnings: ['If untreated, heat exhaustion can progress rapidly to heat stroke.'],
      whatNotToDo: ['Do not drink large amounts of plain water too fast (risk of hyponatremia).'],
      steps: [
        'Move victim to cool, shaded environment.',
        'Loosen heavy clothing.',
        'Provide small sips of cool ORS solution or electrolyte drink.',
        'Have victim lie down and elevate legs slightly.',
        'Cool skin with damp sponge or cloth.'
      ],
    ),
    FirstAidProtocol(
      id: 'env_03',
      title: 'Hypothermia & Cold Exposure',
      category: 'ENVIRONMENTAL',
      urgency: 'CRITICAL',
      overview: 'Re-warming protocol for abnormally low body temperature.',
      equipmentNeeded: 'Dry clothes, warm blankets, warm sweet drink',
      warnings: ['Handle victim extremely gently to avoid triggering cardiac arrest.'],
      whatNotToDo: [
        'Do NOT rub cold skin or limbs briskly.',
        'Do NOT use direct hot water baths or heating lamps.'
      ],
      steps: [
        'Move victim to warm dry shelter.',
        'Remove wet clothing gently.',
        'Warm core body first (chest, neck, groin) using dry blankets and warm body-to-body contact.',
        'Provide warm, sweet non-caffeinated liquids if victim is fully conscious.',
        'Keep victim horizontal and still.'
      ],
    ),
    FirstAidProtocol(
      id: 'env_04',
      title: 'Drowning Rescue & Near-Drowning',
      category: 'ENVIRONMENTAL',
      urgency: 'CRITICAL',
      overview: 'Submersion victim rescue and resuscitation.',
      equipmentNeeded: 'Flotation device, CPR barrier mask, warm blanket',
      warnings: ['Always assume spinal injury if drowning involved diving.'],
      whatNotToDo: ['Do not attempt abdominal thrusts to drain water from lungs.'],
      steps: [
        'Safely extract victim from water without risking rescuer safety.',
        'Check breathing and pulse for 10 seconds.',
        'If not breathing, deliver 5 initial rescue breaths before compressions.',
        'Begin standard CPR (30 compressions : 2 breaths).',
        'Remove wet clothes, wrap in dry blankets, and transport to emergency care.'
      ],
    ),

    // --- POISONING AND EXPOSURE ---
    FirstAidProtocol(
      id: 'pois_01',
      title: 'Ingested Poisoning Management',
      category: 'POISONING',
      urgency: 'CRITICAL',
      overview: 'First aid for ingested toxic chemicals or overdoses.',
      equipmentNeeded: 'Poison Control phone line, chemical container label',
      warnings: ['Have chemical container or substance bottle ready for medical identification.'],
      whatNotToDo: ['NEVER induce vomiting unless explicitly instructed by Poison Control.'],
      steps: [
        'Check victim\'s alertness and breathing.',
        'Contact Poison Control Center or Emergency Responders immediately.',
        'If substance is caustic (acid/lye) and victim is conscious, rinse mouth with water.',
        'Do not give anything to drink unless instructed by medical authority.',
        'If victim vomits, turn onto side to prevent aspiration into lungs.'
      ],
    ),
    FirstAidProtocol(
      id: 'pois_02',
      title: 'Hazardous Chemical Skin Exposure',
      category: 'POISONING',
      urgency: 'HIGH',
      overview: 'Decontamination for chemical spills on skin/body.',
      equipmentNeeded: 'Decontamination shower / hose, clean clothes',
      warnings: ['Responders must wear nitrile/butyl gloves to prevent secondary exposure.'],
      whatNotToDo: ['Do not rub chemical into skin.'],
      steps: [
        'Remove contaminated clothing immediately while flushing.',
        'Flush skin continuously with copious water for at least 20 minutes.',
        'Wash gently with mild soap if chemical is non-reactive with water.',
        'Cover skin with clean cloth.',
        'Seek urgent decontamination facility inspection.'
      ],
    ),
  ];
}

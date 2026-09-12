import 'dart:math';

enum QuizStatus { available, completed, expired }

class QuizWindowInfo {
  final bool isAvailable;
  final String windowId;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime nextWindowStart;

  const QuizWindowInfo({
    required this.isAvailable,
    required this.windowId,
    required this.windowStart,
    required this.windowEnd,
    required this.nextWindowStart,
  });
}

class QuizQuestion {
  final String id;
  final String category; // Transport, Food, Energy, Climate Science, Nature
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      text: json['text'] as String? ?? '',
      options: List<String>.from(json['options'] as List? ?? []),
      correctIndex: json['correctIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'text': text,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }
}

class Quiz {
  final String id;
  final String title;
  final String topic;
  final List<QuizQuestion> questions;
  final DateTime startTime;
  final DateTime endTime;

  const Quiz({
    required this.id,
    required this.title,
    required this.topic,
    required this.questions,
    required this.startTime,
    required this.endTime,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Bi-Weekly Eco Quiz',
      topic: json['topic'] as String? ?? 'General Sustainability',
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      startTime:
          DateTime.tryParse(json['start_time'] as String? ?? '') ??
          DateTime.now().subtract(const Duration(hours: 1)),
      endTime:
          DateTime.tryParse(json['end_time'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 47)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'questions': questions.map((q) => q.toJson()).toList(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
    };
  }
}

class QuizAttemptResult {
  final String quizId;
  final String userId;
  final int score;
  final int totalQuestions;
  final int xpEarned;
  final bool isPerfect;
  final List<int> answers;
  final DateTime completedAt;

  const QuizAttemptResult({
    required this.quizId,
    required this.userId,
    required this.score,
    required this.totalQuestions,
    required this.xpEarned,
    required this.isPerfect,
    required this.answers,
    required this.completedAt,
  });

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    return QuizAttemptResult(
      quizId: json['quiz_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      xpEarned: json['xp_earned'] as int? ?? 0,
      isPerfect: json['is_perfect'] as bool? ?? false,
      answers: List<int>.from(json['answers'] as List? ?? []),
      completedAt:
          DateTime.tryParse(json['completed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'user_id': userId,
      'score': score,
      'total_questions': totalQuestions,
      'xp_earned': xpEarned,
      'is_perfect': isPerfect,
      'answers': answers,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}

class QuizEngine {
  /// Calculate XP earned for a quiz attempt (Section 9.1 & 12.1):
  /// - Base attempt XP: 30 XP (for submitting)
  /// - Per correct answer: +5 XP per question
  /// - Perfect score bonus (10/10): +50 XP — Level 5+ users only!
  /// Max total: 80 XP (Level 1-4) / 130 XP (Level 5+)
  static Map<String, dynamic> calculateQuizXp({
    required int score,
    required int totalQuestions,
    required int level,
  }) {
    const baseAttemptXp = 30;
    final perQuestionBonus = score * 5;
    final isPerfect = score > 0 && score == totalQuestions;

    // Perfect score bonus (+50 XP) is available ONLY at Level 5+
    final perfectBonus = (isPerfect && level >= 5) ? 50 : 0;
    final totalXp = baseAttemptXp + perQuestionBonus + perfectBonus;

    return {
      'baseAttemptXp': baseAttemptXp,
      'perQuestionBonus': perQuestionBonus,
      'perfectBonus': perfectBonus,
      'totalXp': totalXp,
      'isPerfect': isPerfect,
    };
  }

  static QuizStatus getQuizStatus({
    required Quiz quiz,
    required DateTime? completedAt,
    required DateTime now,
  }) {
    if (completedAt != null) return QuizStatus.completed;
    if (now.isBefore(quiz.startTime) || now.isAfter(quiz.endTime)) {
      return QuizStatus.expired;
    }
    return QuizStatus.available;
  }

  static Duration getRemainingWindowDuration({
    required Quiz quiz,
    required DateTime now,
  }) {
    if (now.isAfter(quiz.endTime)) return Duration.zero;
    return quiz.endTime.difference(now);
  }

  // --- 50 Question Bank (Section 9.2 - 9.6) ---
  static const List<QuizQuestion> fullQuestionBank = [
    // Transport (Q1 - Q10)
    QuizQuestion(
      id: 'q1',
      category: 'Transport',
      text: 'Which vehicle type produces the least CO₂ per kilometre?',
      options: ['Petrol car', 'Diesel car', 'Electric vehicle', 'Motorcycle'],
      correctIndex: 2,
      explanation:
          'EVs produce zero tailpipe emissions and significantly lower lifecycle carbon emissions.',
    ),
    QuizQuestion(
      id: 'q2',
      category: 'Transport',
      text:
          'Approximately how many kg of CO₂ does a long-haul flight emit per passenger per hour?',
      options: ['5 kg', '90 kg', '250 kg', '1,000 kg'],
      correctIndex: 1,
      explanation:
          'Long-haul flights average around 90 kg of CO₂ emissions per passenger hour.',
    ),
    QuizQuestion(
      id: 'q3',
      category: 'Transport',
      text: 'What is carpooling most effective at reducing?',
      options: [
        'Fuel cost only',
        'Per-person carbon emissions',
        'Road wear and tear',
        'Journey time',
      ],
      correctIndex: 1,
      explanation:
          'Sharing rides distributes vehicle emissions among passengers, drastically cutting per-person carbon.',
    ),
    QuizQuestion(
      id: 'q4',
      category: 'Transport',
      text: 'Which has the lowest carbon footprint per passenger-kilometre?',
      options: [
        'Domestic flight',
        'Electric car (average grid)',
        'Full inter-city train',
        'Empty bus',
      ],
      correctIndex: 2,
      explanation:
          'Full inter-city electric trains are among the most carbon-efficient passenger travel modes.',
    ),
    QuizQuestion(
      id: 'q5',
      category: 'Transport',
      text:
          'What percentage of global CO₂ emissions does the transport sector account for?',
      options: ['7%', '16%', '24%', '38%'],
      correctIndex: 2,
      explanation:
          'Transport accounts for approximately 24% of global energy-related CO₂ emissions.',
    ),
    QuizQuestion(
      id: 'q6',
      category: 'Transport',
      text:
          "A hybrid car's fuel efficiency is greatest during which type of driving?",
      options: [
        'Motorway cruising at high speed',
        'Stop-start urban driving',
        'Long uphill climbs',
        'Cold weather driving',
      ],
      correctIndex: 1,
      explanation:
          'Regenerative braking in stop-start urban traffic recharges hybrid batteries continuously.',
    ),
    QuizQuestion(
      id: 'q7',
      category: 'Transport',
      text:
          'A petrol car emits 180g CO₂ per km. How much CO₂ is produced on a 50 km journey?',
      options: ['5 kg', '9 kg', '18 kg', '25 kg'],
      correctIndex: 1,
      explanation: '180g * 50 km = 9,000g = 9 kg of CO₂.',
    ),
    QuizQuestion(
      id: 'q8',
      category: 'Transport',
      text:
          'Which transport fuel is produced from biological material such as crops or waste?',
      options: ['Hydrogen', 'Biofuel', 'LPG', 'Synthetic diesel'],
      correctIndex: 1,
      explanation:
          'Biofuels are derived from organic matter such as plants, algae, or agricultural waste.',
    ),
    QuizQuestion(
      id: 'q9',
      category: 'Transport',
      text: "What is 'range anxiety' in the context of electric vehicles?",
      options: [
        'Fear of driving in heavy rain',
        'Concern about running out of battery before reaching a charger',
        'Anxiety about purchase price',
        'Worry about battery fires',
      ],
      correctIndex: 1,
      explanation:
          'Range anxiety refers to driver fear that an EV will run out of charge mid-trip.',
    ),
    QuizQuestion(
      id: 'q10',
      category: 'Transport',
      text:
          'Cycling instead of driving 5 km per day for a year saves approximately how much CO₂?',
      options: ['50 kg', '200 kg', '330 kg', '600 kg'],
      correctIndex: 2,
      explanation:
          'Riding a bike 5 km daily prevents approx 330 kg of vehicle CO₂ emissions annually.',
    ),

    // Food (Q11 - Q20)
    QuizQuestion(
      id: 'q11',
      category: 'Food',
      text: 'Which food has the highest carbon footprint per 100g produced?',
      options: ['Lentils', 'Chicken', 'Beef', 'Tofu'],
      correctIndex: 2,
      explanation:
          'Beef requires extensive land and produces high enteric methane emissions.',
    ),
    QuizQuestion(
      id: 'q12',
      category: 'Food',
      text: "What does 'food miles' refer to?",
      options: [
        'Calories burned during cooking',
        'Distance food travels from farm to plate',
        'Amount of food wasted annually',
        'Nutritional value per serving',
      ],
      correctIndex: 1,
      explanation:
          'Food miles represent the supply-chain distance food travels from production to consumer.',
    ),
    QuizQuestion(
      id: 'q13',
      category: 'Food',
      text: 'Eating seasonally helps reduce emissions because:',
      options: [
        'Seasonal food is always organic',
        'Local seasonal food needs less transport and refrigeration',
        'Seasonal food has fewer pesticides',
        'It is lower in calories',
      ],
      correctIndex: 1,
      explanation:
          'Seasonal local produce avoids heated greenhouse cultivation and long cold-chain transport.',
    ),
    QuizQuestion(
      id: 'q14',
      category: 'Food',
      text:
          "Which dietary shift would reduce a person's food carbon footprint the most?",
      options: [
        'Switching from tap to bottled water',
        'Eliminating beef and lamb',
        'Buying only branded products',
        'Switching from glass to plastic packaging',
      ],
      correctIndex: 1,
      explanation:
          'Ruminants (beef & lamb) account for the highest greenhouse gas intensity of all major foods.',
    ),
    QuizQuestion(
      id: 'q15',
      category: 'Food',
      text:
          'What fraction of global greenhouse gas emissions comes from food production?',
      options: ['5%', '10%', '25%', '50%'],
      correctIndex: 2,
      explanation:
          'Food systems account for roughly 25-30% of global greenhouse gas emissions.',
    ),
    QuizQuestion(
      id: 'q16',
      category: 'Food',
      text: 'Which of the following produces the most methane?',
      options: [
        'Crop irrigation',
        'Livestock digestion (enteric fermentation)',
        'Refrigerated transport',
        'Plastic packaging production',
      ],
      correctIndex: 1,
      explanation:
          'Enteric fermentation in cattle and sheep is the largest agricultural methane source.',
    ),
    QuizQuestion(
      id: 'q17',
      category: 'Food',
      text: "What does 'plant-based diet' mean?",
      options: [
        'Only eating raw food',
        'A diet centred on plants, minimising animal products',
        'Only eating food grown without pesticides',
        'A purely vegan diet with no exceptions',
      ],
      correctIndex: 1,
      explanation:
          'Plant-based diets prioritize foods derived from plants while minimizing animal products.',
    ),
    QuizQuestion(
      id: 'q18',
      category: 'Food',
      text: 'How does food waste contribute to climate change?',
      options: [
        'It produces noise pollution',
        'Decomposing food in landfill releases methane',
        'It uses up oxygen in soil',
        'It has no climate impact',
      ],
      correctIndex: 1,
      explanation:
          'Anaerobic decomposition of landfilled organic waste generates potent methane gas.',
    ),
    QuizQuestion(
      id: 'q19',
      category: 'Food',
      text: 'Which farming practice helps soil absorb more carbon?',
      options: [
        'Deep ploughing every season',
        'Monoculture farming',
        'Cover cropping and reduced tillage',
        'More synthetic nitrogen fertiliser',
      ],
      correctIndex: 2,
      explanation:
          'No-till farming and cover cropping maintain soil organic matter and sequester carbon.',
    ),
    QuizQuestion(
      id: 'q20',
      category: 'Food',
      text: 'On average, how much CO₂-equivalent does 1 kg of beef produce?',
      options: ['3 kg', '10 kg', '27 kg', '60 kg'],
      correctIndex: 3,
      explanation:
          'Producing 1 kg of beef generates on average 60 kg CO₂ equivalent.',
    ),

    // Energy (Q21 - Q30)
    QuizQuestion(
      id: 'q21',
      category: 'Energy',
      text:
          'Which household appliance typically consumes the most electricity per year?',
      options: ['LED bulb', 'Laptop', 'Refrigerator', 'Phone charger'],
      correctIndex: 2,
      explanation:
          'Refrigerators run 24/7/365, consuming significant cumulative power annualy.',
    ),
    QuizQuestion(
      id: 'q22',
      category: 'Energy',
      text: "What does 'phantom load' refer to?",
      options: [
        'Energy lost in power line transmission',
        'Electricity used by devices on standby',
        'Peak demand during grid surges',
        'Energy produced by solar at night',
      ],
      correctIndex: 1,
      explanation:
          'Phantom load is standby power consumed by electronic devices when turned off or idle.',
    ),
    QuizQuestion(
      id: 'q23',
      category: 'Energy',
      text:
          'Lowering your thermostat by 1°C reduces heating bills by approximately:',
      options: ['0.5%', '10%', '30%', '50%'],
      correctIndex: 1,
      explanation:
          'Reducing indoor temperatures by 1°C cuts space heating energy consumption by ~10%.',
    ),
    QuizQuestion(
      id: 'q24',
      category: 'Energy',
      text: 'Which of the following is a renewable energy source?',
      options: ['Natural gas', 'Coal', 'Onshore wind', 'Nuclear fission'],
      correctIndex: 2,
      explanation:
          'Wind power generates zero-emission electricity from naturally recurring air currents.',
    ),
    QuizQuestion(
      id: 'q25',
      category: 'Energy',
      text: "What is the 'carbon intensity' of an electricity grid?",
      options: [
        'Weight of power cables per km',
        'CO₂ emitted per unit of electricity generated (kg CO₂/kWh)',
        'Cost of electricity per unit',
        'Efficiency of solar panels',
      ],
      correctIndex: 1,
      explanation:
          'Carbon intensity measures grams/kilograms of CO₂ produced per kilowatt-hour of power.',
    ),
    QuizQuestion(
      id: 'q26',
      category: 'Energy',
      text: 'Which action saves the most energy in a typical home?',
      options: [
        'Switching off lights when leaving',
        'Upgrading to a more efficient boiler or heat pump',
        'Unplugging phone chargers',
        'Using a microwave instead of an oven',
      ],
      correctIndex: 1,
      explanation:
          'Space heating accounts for ~50% of home energy; heat pumps drastically reduce fuel energy.',
    ),
    QuizQuestion(
      id: 'q27',
      category: 'Energy',
      text: "What does a solar panel's 'peak watt' rating measure?",
      options: [
        'Power output in full direct sunlight',
        'Total lifetime energy output',
        'Power stored in the battery',
        'Efficiency in cloudy weather',
      ],
      correctIndex: 0,
      explanation:
          'Peak watt (Wp) is maximum output generated under standard test conditions (1000 W/m² sunlight).',
    ),
    QuizQuestion(
      id: 'q28',
      category: 'Energy',
      text: 'Heat pumps are more efficient than gas boilers because they:',
      options: [
        'Burn fuel more cleanly',
        'Generate heat at higher combustion temperatures',
        'Transfer heat from outside air or ground rather than burning fuel',
        'Produce no noise',
      ],
      correctIndex: 2,
      explanation:
          'Heat pumps transfer thermal energy from outdoor air or soil, achieving >300% efficiency.',
    ),
    QuizQuestion(
      id: 'q29',
      category: 'Energy',
      text: "Which best describes 'net zero' energy in a building?",
      options: [
        'The building uses no energy at all',
        'Energy consumed equals energy generated on-site over a year',
        'The building only uses energy at night',
        'The building has no heating system',
      ],
      correctIndex: 1,
      explanation:
          'Net-zero buildings produce as much clean renewable energy as they consume annually.',
    ),
    QuizQuestion(
      id: 'q30',
      category: 'Energy',
      text:
          "What percentage of a typical home's energy use goes to space heating?",
      options: ['10%', '30%', '50%', '70%'],
      correctIndex: 2,
      explanation:
          'In temperate climates, heating indoor space makes up approximately 50% of home energy usage.',
    ),

    // Climate Science (Q31 - Q40)
    QuizQuestion(
      id: 'q31',
      category: 'Climate Science',
      text: 'The main greenhouse gas produced by human activity is:',
      options: ['Oxygen', 'Nitrogen', 'CO₂', 'Argon'],
      correctIndex: 2,
      explanation:
          'Carbon dioxide makes up over 75% of human-driven global greenhouse gas emissions.',
    ),
    QuizQuestion(
      id: 'q32',
      category: 'Climate Science',
      text: "What is the 'greenhouse effect'?",
      options: [
        'Crops growing faster in warmer climates',
        'The trapping of heat by atmospheric gases, warming the Earth\'s surface',
        'The melting of polar ice caps',
        'Growing food in heated glass structures',
      ],
      correctIndex: 1,
      explanation:
          'Atmospheric gases trap solar thermal radiation near Earth’s surface, raising planetary temperatures.',
    ),
    QuizQuestion(
      id: 'q33',
      category: 'Climate Science',
      text: 'Pre-industrial atmospheric CO₂ levels were approximately:',
      options: ['180 ppm', '280 ppm', '420 ppm', '550 ppm'],
      correctIndex: 1,
      explanation:
          'Pre-industrial CO₂ concentration was stable at approximately 280 parts per million.',
    ),
    QuizQuestion(
      id: 'q34',
      category: 'Climate Science',
      text: 'What does the Paris Agreement aim to limit global warming to?',
      options: [
        '0.5°C above pre-industrial levels',
        '1.5–2°C above pre-industrial levels',
        '3°C above pre-industrial levels',
        'Any amount as long as emissions are reduced',
      ],
      correctIndex: 1,
      explanation:
          'The Paris Agreement targets keeping global warming well below 2°C, preferably 1.5°C.',
    ),
    QuizQuestion(
      id: 'q35',
      category: 'Climate Science',
      text:
          'Which gas has a global warming potential approximately 28× higher than CO₂ over 100 years?',
      options: ['Oxygen', 'Nitrogen', 'Methane', 'Argon'],
      correctIndex: 2,
      explanation:
          'Methane (CH₄) traps 28 to 36 times more heat than CO₂ over a 100-year timescale.',
    ),
    QuizQuestion(
      id: 'q36',
      category: 'Climate Science',
      text: 'Ocean acidification is caused by:',
      options: [
        'Ship pollution',
        'The ocean absorbing excess CO₂ from the atmosphere',
        'Overfishing',
        'Volcanic eruptions on the ocean floor',
      ],
      correctIndex: 1,
      explanation:
          'Oceans absorb ~30% of emitted CO₂, forming carbonic acid and lowering seawater pH.',
    ),
    QuizQuestion(
      id: 'q37',
      category: 'Climate Science',
      text: "What does 'carbon sequestration' mean?",
      options: [
        'Burning carbon fuels more efficiently',
        'Capturing and storing CO₂ from the atmosphere',
        'Measuring the carbon content of soil',
        'Calculating a country\'s total emissions',
      ],
      correctIndex: 1,
      explanation:
          'Carbon sequestration captures atmospheric CO₂ in long-term sinks like forests, soils, or geological storage.',
    ),
    QuizQuestion(
      id: 'q38',
      category: 'Climate Science',
      text: 'Which decade was the hottest on record as of 2024?',
      options: ['1990s', '2000s', '2010s', '2020s'],
      correctIndex: 3,
      explanation:
          'Global average temperatures reached unprecedented highs in the 2020s.',
    ),
    QuizQuestion(
      id: 'q39',
      category: 'Climate Science',
      text: "What is an 'emissions offset'?",
      options: [
        'A fine for exceeding emission limits',
        'A reduction in emissions elsewhere to compensate for your own',
        'A government subsidy for clean energy',
        'A type of renewable fuel',
      ],
      correctIndex: 1,
      explanation:
          'Carbon offsets balance personal/corporate footprint by funding verified carbon reduction projects.',
    ),
    QuizQuestion(
      id: 'q40',
      category: 'Climate Science',
      text:
          'Approximately how many trees offset one tonne of CO₂ over 40 years?',
      options: ['1', '6', '50', '200'],
      correctIndex: 2,
      explanation:
          'It takes roughly 50 mature trees 40 years to absorb 1 metric tonne of CO₂.',
    ),

    // Nature & Sustainability (Q41 - Q50)
    QuizQuestion(
      id: 'q41',
      category: 'Nature',
      text:
          "What percentage of the world's biodiversity is found in tropical rainforests?",
      options: ['10%', '25%', '50%', '80%'],
      correctIndex: 2,
      explanation:
          'Tropical rainforests house over 50% of all terrestrial plant and animal species.',
    ),
    QuizQuestion(
      id: 'q42',
      category: 'Nature',
      text: "What is 'fast fashion' primarily criticised for environmentally?",
      options: [
        'Using only synthetic dyes',
        'High volume production leading to massive textile waste and carbon emissions',
        'Making clothing too expensive',
        'Clothes that wear out too quickly',
      ],
      correctIndex: 1,
      explanation:
          'Fast fashion drives high resource consumption, microplastic pollution, and landfill waste.',
    ),
    QuizQuestion(
      id: 'q43',
      category: 'Nature',
      text: 'Plastic takes approximately how long to decompose in landfill?',
      options: [
        '10–20 years',
        '50–100 years',
        '200–500 years',
        'Thousands of years',
      ],
      correctIndex: 2,
      explanation:
          'Standard synthetic plastics take 200 to 500 years to break down in landfills.',
    ),
    QuizQuestion(
      id: 'q44',
      category: 'Nature',
      text: 'What is the circular economy?',
      options: [
        'An economy focused on circular trade routes',
        'A system designed to eliminate waste by keeping materials in use as long as possible',
        'A stock market cycle theory',
        'A farming technique that rotates crops in a circle',
      ],
      correctIndex: 1,
      explanation:
          'Circular economies design out waste through continuous reuse, repair, remanufacturing, and recycling.',
    ),
    QuizQuestion(
      id: 'q45',
      category: 'Nature',
      text:
          'The most effective way to reduce your personal water footprint is:',
      options: [
        'Taking shorter showers',
        'Drinking only bottled water',
        'Reducing consumption of meat and dairy',
        'Installing a water butt',
      ],
      correctIndex: 2,
      explanation:
          'Agricultural water for animal feed dominates virtual water footprints (1 kg beef requires 15,000L water).',
    ),
    QuizQuestion(
      id: 'q46',
      category: 'Nature',
      text: "What does 'biodegradable' mean?",
      options: [
        'Can be recycled into new products',
        'Breaks down naturally by microorganisms without leaving toxic residue',
        'Made from plant-based materials',
        'Produces no greenhouse gases during production',
      ],
      correctIndex: 1,
      explanation:
          'Biodegradable items decompose back into natural elements through biological action.',
    ),
    QuizQuestion(
      id: 'q47',
      category: 'Nature',
      text:
          'Which human activity is the leading driver of deforestation globally?',
      options: [
        'Urban expansion',
        'Mining and oil extraction',
        'Agricultural land clearance for livestock and crops',
        'Paper production',
      ],
      correctIndex: 2,
      explanation:
          'Forest clearance for cattle ranching, soy, and palm oil accounts for ~80% of global deforestation.',
    ),
    QuizQuestion(
      id: 'q48',
      category: 'Nature',
      text: "What is 'greenwashing'?",
      options: [
        'Painting buildings green to reflect sunlight',
        'Marketing that exaggerates or falsely claims a product\'s environmental benefits',
        'Washing clothing at low temperatures',
        'A government policy to tax high-emission products',
      ],
      correctIndex: 1,
      explanation:
          'Greenwashing tricks consumers into believing a company or product is eco-friendly when it is not.',
    ),
    QuizQuestion(
      id: 'q49',
      category: 'Nature',
      text: 'Composting organic waste helps the environment primarily by:',
      options: [
        'Creating plastic alternatives',
        'Returning nutrients to soil and reducing methane from landfill',
        'Producing clean energy',
        'Purifying water sources',
      ],
      correctIndex: 1,
      explanation:
          'Composting diverts organics from anaerobic landfills, enriching soils without synthetic fertilizers.',
    ),
    QuizQuestion(
      id: 'q50',
      category: 'Nature',
      text: "Which best describes 'sustainable development'?",
      options: [
        'Development using as many resources as possible now',
        'Development that meets today\'s needs without compromising future generations\' ability to meet theirs',
        'Development exclusively in rural areas',
        'Development funded by environmental charities',
      ],
      correctIndex: 1,
      explanation:
          'Defined by the UN Brundtland Commission as meeting present needs without compromising future generations.',
    ),
  ];

  /// Deterministic bi-weekly quiz window helper (Section 9.1)
  /// Active Windows:
  /// - Tuesday 09:00 AM to Thursday 09:00 AM (48 Hours)
  /// - Friday 09:00 AM to Sunday 09:00 AM (48 Hours)
  static QuizWindowInfo getQuizWindowInfo(DateTime now) {
    // Tuesday 09:00 AM of this week
    final daysFromTue = (now.weekday - DateTime.tuesday) % 7;
    final thisTueDate = now.subtract(Duration(days: daysFromTue));
    final tueStart = DateTime(
      thisTueDate.year,
      thisTueDate.month,
      thisTueDate.day,
      9,
      0,
    );
    final tueEnd = tueStart.add(const Duration(hours: 48));

    // Friday 09:00 AM of this week
    final daysFromFri = (now.weekday - DateTime.friday) % 7;
    final thisFriDate = now.subtract(Duration(days: daysFromFri));
    final friStart = DateTime(
      thisFriDate.year,
      thisFriDate.month,
      thisFriDate.day,
      9,
      0,
    );
    final friEnd = friStart.add(const Duration(hours: 48));

    // Check Tuesday window (Tuesday 9 AM to Thursday 9 AM)
    if (!now.isBefore(tueStart) && now.isBefore(tueEnd)) {
      final wId =
          'quiz_${tueStart.year}_${tueStart.month.toString().padLeft(2, '0')}_${tueStart.day.toString().padLeft(2, '0')}_tue';
      final nextStart = friStart.isBefore(tueStart)
          ? friStart.add(const Duration(days: 7))
          : friStart;
      return QuizWindowInfo(
        isAvailable: true,
        windowId: wId,
        windowStart: tueStart,
        windowEnd: tueEnd,
        nextWindowStart: nextStart,
      );
    }

    // Check Friday window (Friday 9 AM to Sunday 9 AM)
    if (!now.isBefore(friStart) && now.isBefore(friEnd)) {
      final wId =
          'quiz_${friStart.year}_${friStart.month.toString().padLeft(2, '0')}_${friStart.day.toString().padLeft(2, '0')}_fri';
      final nextStart = tueStart.isBefore(friStart)
          ? tueStart.add(const Duration(days: 7))
          : tueStart;
      return QuizWindowInfo(
        isAvailable: true,
        windowId: wId,
        windowStart: friStart,
        windowEnd: friEnd,
        nextWindowStart: nextStart,
      );
    }

    // Outside both 48h windows — calculate next window start time
    DateTime nextWindow;
    if (now.isBefore(tueStart)) {
      nextWindow = tueStart;
    } else if (now.isBefore(friStart)) {
      nextWindow = friStart;
    } else {
      nextWindow = tueStart.add(const Duration(days: 7));
    }

    return QuizWindowInfo(
      isAvailable: false,
      windowId: 'quiz_inactive_${now.year}_${now.month}_${now.day}',
      windowStart: now,
      windowEnd: now,
      nextWindowStart: nextWindow,
    );
  }

  /// Get sample 10 questions for a quiz session (2 per category randomly selected from 50 bank)
  static Quiz getSampleQuiz({
    QuizWindowInfo? windowInfo,
    DateTime? startTime,
    int sessionIndex = 0,
  }) {
    final info = windowInfo ?? getQuizWindowInfo(startTime ?? DateTime.now());
    final rand = Random(info.windowId.hashCode + sessionIndex);

    final selectedQuestions = <QuizQuestion>[];
    final categories = [
      'Transport',
      'Food',
      'Energy',
      'Climate Science',
      'Nature',
    ];

    for (var cat in categories) {
      final catQuestions = fullQuestionBank
          .where((q) => q.category == cat)
          .toList();
      catQuestions.shuffle(rand);
      selectedQuestions.addAll(catQuestions.take(2));
    }

    if (selectedQuestions.length < 10) {
      final remaining = fullQuestionBank
          .where((q) => !selectedQuestions.contains(q))
          .toList();
      remaining.shuffle(rand);
      selectedQuestions.addAll(remaining.take(10 - selectedQuestions.length));
    }

    return Quiz(
      id: info.windowId,
      title: 'Bi-Weekly Eco Quiz',
      topic: 'Sustainability & Carbon Science',
      questions: selectedQuestions,
      startTime: info.windowStart,
      endTime: info.windowEnd,
    );
  }
}

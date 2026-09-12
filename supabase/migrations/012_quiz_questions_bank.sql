-- NeutraWise Gamification v2: Expanded 50 Question Quiz Bank Migration
-- Migration script 012_quiz_questions_bank.sql

-- 1. Create quiz_questions table
CREATE TABLE IF NOT EXISTS quiz_questions (
  id VARCHAR PRIMARY KEY,
  category VARCHAR NOT NULL,
  question TEXT NOT NULL,
  options JSONB NOT NULL,
  correct_index INT NOT NULL,
  explanation TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE quiz_questions ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow authenticated read on quiz_questions') THEN
    CREATE POLICY "Allow authenticated read on quiz_questions" ON quiz_questions
      FOR SELECT USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- 2. Create user_quizzes table for completion tracking
CREATE TABLE IF NOT EXISTS user_quizzes (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quiz_id VARCHAR NOT NULL,
  score INT NOT NULL DEFAULT 0,
  total_questions INT NOT NULL DEFAULT 10,
  xp_earned INT NOT NULL DEFAULT 0,
  is_perfect BOOLEAN NOT NULL DEFAULT FALSE,
  answers JSONB DEFAULT '[]'::jsonb,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, quiz_id)
);

ALTER TABLE user_quizzes ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can manage own user_quizzes') THEN
    CREATE POLICY "Users can manage own user_quizzes" ON user_quizzes
      FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- 3. Seed All 50 Questions (Section 9.2 - 9.6)
INSERT INTO quiz_questions (id, category, question, options, correct_index, explanation)
VALUES
  -- Transport (Q1 - Q10)
  ('q1', 'Transport', 'Which vehicle type produces the least CO₂ per kilometre?', '["Petrol car", "Diesel car", "Electric vehicle", "Motorcycle"]'::jsonb, 2, 'EVs produce zero tailpipe emissions and significantly lower lifecycle carbon emissions.'),
  ('q2', 'Transport', 'Approximately how many kg of CO₂ does a long-haul flight emit per passenger per hour?', '["5 kg", "90 kg", "250 kg", "1,000 kg"]'::jsonb, 1, 'Long-haul flights average around 90 kg of CO₂ emissions per passenger hour.'),
  ('q3', 'Transport', 'What is carpooling most effective at reducing?', '["Fuel cost only", "Per-person carbon emissions", "Road wear and tear", "Journey time"]'::jsonb, 1, 'Sharing rides distributes vehicle emissions among passengers, drastically cutting per-person carbon.'),
  ('q4', 'Transport', 'Which has the lowest carbon footprint per passenger-kilometre?', '["Domestic flight", "Electric car (average grid)", "Full inter-city train", "Empty bus"]'::jsonb, 2, 'Full inter-city electric trains are among the most carbon-efficient passenger travel modes.'),
  ('q5', 'Transport', 'What percentage of global CO₂ emissions does the transport sector account for?', '["7%", "16%", "24%", "38%"]'::jsonb, 2, 'Transport accounts for approximately 24% of global energy-related CO₂ emissions.'),
  ('q6', 'Transport', 'A hybrid car''s fuel efficiency is greatest during which type of driving?', '["Motorway cruising at high speed", "Stop-start urban driving", "Long uphill climbs", "Cold weather driving"]'::jsonb, 1, 'Regenerative braking in stop-start urban traffic recharges hybrid batteries continuously.'),
  ('q7', 'Transport', 'A petrol car emits 180g CO₂ per km. How much CO₂ is produced on a 50 km journey?', '["5 kg", "9 kg", "18 kg", "25 kg"]'::jsonb, 1, '180g * 50 km = 9,000g = 9 kg of CO₂.'),
  ('q8', 'Transport', 'Which transport fuel is produced from biological material such as crops or waste?', '["Hydrogen", "Biofuel", "LPG", "Synthetic diesel"]'::jsonb, 1, 'Biofuels are derived from organic matter such as plants, algae, or agricultural waste.'),
  ('q9', 'Transport', 'What is ''range anxiety'' in the context of electric vehicles?', '["Fear of driving in heavy rain", "Concern about running out of battery before reaching a charger", "Anxiety about purchase price", "Worry about battery fires"]'::jsonb, 1, 'Range anxiety refers to driver fear that an EV will run out of charge mid-trip.'),
  ('q10', 'Transport', 'Cycling instead of driving 5 km per day for a year saves approximately how much CO₂?', '["50 kg", "200 kg", "330 kg", "600 kg"]'::jsonb, 2, 'Riding a bike 5 km daily prevents approx 330 kg of vehicle CO₂ emissions annually.'),

  -- Food (Q11 - Q20)
  ('q11', 'Food', 'Which food has the highest carbon footprint per 100g produced?', '["Lentils", "Chicken", "Beef", "Tofu"]'::jsonb, 2, 'Beef requires extensive land and produces high enteric methane emissions.'),
  ('q12', 'Food', 'What does ''food miles'' refer to?', '["Calories burned during cooking", "Distance food travels from farm to plate", "Amount of food wasted annually", "Nutritional value per serving"]'::jsonb, 1, 'Food miles represent the supply-chain distance food travels from production to consumer.'),
  ('q13', 'Food', 'Eating seasonally helps reduce emissions because:', '["Seasonal food is always organic", "Local seasonal food needs less transport and refrigeration", "Seasonal food has fewer pesticides", "It is lower in calories"]'::jsonb, 1, 'Seasonal local produce avoids heated greenhouse cultivation and long cold-chain transport.'),
  ('q14', 'Food', 'Which dietary shift would reduce a person''s food carbon footprint the most?', '["Switching from tap to bottled water", "Eliminating beef and lamb", "Buying only branded products", "Switching from glass to plastic packaging"]'::jsonb, 1, 'Ruminants (beef & lamb) account for the highest greenhouse gas intensity of all major foods.'),
  ('q15', 'Food', 'What fraction of global greenhouse gas emissions comes from food production?', '["5%", "10%", "25%", "50%"]'::jsonb, 2, 'Food systems account for roughly 25-30% of global greenhouse gas emissions.'),
  ('q16', 'Food', 'Which of the following produces the most methane?', '["Crop irrigation", "Livestock digestion (enteric fermentation)", "Refrigerated transport", "Plastic packaging production"]'::jsonb, 1, 'Enteric fermentation in cattle and sheep is the largest agricultural methane source.'),
  ('q17', 'Food', 'What does ''plant-based diet'' mean?', '["Only eating raw food", "A diet centred on plants, minimising animal products", "Only eating food grown without pesticides", "A purely vegan diet with no exceptions"]'::jsonb, 1, 'Plant-based diets prioritize foods derived from plants while minimizing animal products.'),
  ('q18', 'Food', 'How does food waste contribute to climate change?', '["It produces noise pollution", "Decomposing food in landfill releases methane", "It uses up oxygen in soil", "It has no climate impact"]'::jsonb, 1, 'Anaerobic decomposition of landfilled organic waste generates potent methane gas.'),
  ('q19', 'Food', 'Which farming practice helps soil absorb more carbon?', '["Deep ploughing every season", "Monoculture farming", "Cover cropping and reduced tillage", "More synthetic nitrogen fertiliser"]'::jsonb, 2, 'No-till farming and cover cropping maintain soil organic matter and sequester carbon.'),
  ('q20', 'Food', 'On average, how much CO₂-equivalent does 1 kg of beef produce?', '["3 kg", "10 kg", "27 kg", "60 kg"]'::jsonb, 3, 'Producing 1 kg of beef generates on average 60 kg CO₂ equivalent.'),

  -- Energy (Q21 - Q30)
  ('q21', 'Energy', 'Which household appliance typically consumes the most electricity per year?', '["LED bulb", "Laptop", "Refrigerator", "Phone charger"]'::jsonb, 2, 'Refrigerators run 24/7/365, consuming significant cumulative power annualy.'),
  ('q22', 'Energy', 'What does ''phantom load'' refer to?', '["Energy lost in power line transmission", "Electricity used by devices on standby", "Peak demand during grid surges", "Energy produced by solar at night"]'::jsonb, 1, 'Phantom load is standby power consumed by electronic devices when turned off or idle.'),
  ('q23', 'Energy', 'Lowering your thermostat by 1°C reduces heating bills by approximately:', '["0.5%", "10%", "30%", "50%"]'::jsonb, 1, 'Reducing indoor temperatures by 1°C cuts space heating energy consumption by ~10%.'),
  ('q24', 'Energy', 'Which of the following is a renewable energy source?', '["Natural gas", "Coal", "Onshore wind", "Nuclear fission"]'::jsonb, 2, 'Wind power generates zero-emission electricity from naturally recurring air currents.'),
  ('q25', 'Energy', 'What is the ''carbon intensity'' of an electricity grid?', '["Weight of power cables per km", "CO₂ emitted per unit of electricity generated (kg CO₂/kWh)", "Cost of electricity per unit", "Efficiency of solar panels"]'::jsonb, 1, 'Carbon intensity measures grams/kilograms of CO₂ produced per kilowatt-hour of power.'),
  ('q26', 'Energy', 'Which action saves the most energy in a typical home?', '["Switching off lights when leaving", "Upgrading to a more efficient boiler or heat pump", "Unplugging phone chargers", "Using a microwave instead of an oven"]'::jsonb, 1, 'Space heating accounts for ~50% of home energy; heat pumps drastically reduce fuel energy.'),
  ('q27', 'Energy', 'What does a solar panel''s ''peak watt'' rating measure?', '["Power output in full direct sunlight", "Total lifetime energy output", "Power stored in the battery", "Efficiency in cloudy weather"]'::jsonb, 0, 'Peak watt (Wp) is maximum output generated under standard test conditions (1000 W/m² sunlight).'),
  ('q28', 'Energy', 'Heat pumps are more efficient than gas boilers because they:', '["Burn fuel more cleanly", "Generate heat at higher combustion temperatures", "Transfer heat from outside air or ground rather than burning fuel", "Produce no noise"]'::jsonb, 2, 'Heat pumps transfer thermal energy from outdoor air or soil, achieving >300% efficiency.'),
  ('q29', 'Energy', 'Which best describes ''net zero'' energy in a building?', '["The building uses no energy at all", "Energy consumed equals energy generated on-site over a year", "The building only uses energy at night", "The building has no heating system"]'::jsonb, 1, 'Net-zero buildings produce as much clean renewable energy as they consume annually.'),
  ('q30', 'Energy', 'What percentage of a typical home''s energy use goes to space heating?', '["10%", "30%", "50%", "70%"]'::jsonb, 2, 'In temperate climates, heating indoor space makes up approximately 50% of home energy usage.'),

  -- Climate Science (Q31 - Q40)
  ('q31', 'Climate Science', 'The main greenhouse gas produced by human activity is:', '["Oxygen", "Nitrogen", "CO₂", "Argon"]'::jsonb, 2, 'Carbon dioxide makes up over 75% of human-driven global greenhouse gas emissions.'),
  ('q32', 'Climate Science', 'What is the ''greenhouse effect''?', '["Crops growing faster in warmer climates", "The trapping of heat by atmospheric gases, warming the Earth''s surface", "The melting of polar ice caps", "Growing food in heated glass structures"]'::jsonb, 1, 'Atmospheric gases trap solar thermal radiation near Earth’s surface, raising planetary temperatures.'),
  ('q33', 'Climate Science', 'Pre-industrial atmospheric CO₂ levels were approximately:', '["180 ppm", "280 ppm", "420 ppm", "550 ppm"]'::jsonb, 1, 'Pre-industrial CO₂ concentration was stable at approximately 280 parts per million.'),
  ('q34', 'Climate Science', 'What does the Paris Agreement aim to limit global warming to?', '["0.5°C above pre-industrial levels", "1.5–2°C above pre-industrial levels", "3°C above pre-industrial levels", "Any amount as long as emissions are reduced"]'::jsonb, 1, 'The Paris Agreement targets keeping global warming well below 2°C, preferably 1.5°C.'),
  ('q35', 'Climate Science', 'Which gas has a global warming potential approximately 28× higher than CO₂ over 100 years?', '["Oxygen", "Nitrogen", "Methane", "Argon"]'::jsonb, 2, 'Methane (CH₄) traps 28 to 36 times more heat than CO₂ over a 100-year timescale.'),
  ('q36', 'Climate Science', 'Ocean acidification is caused by:', '["Ship pollution", "The ocean absorbing excess CO₂ from the atmosphere", "Overfishing", "Volcanic eruptions on the ocean floor"]'::jsonb, 1, 'Oceans absorb ~30% of emitted CO₂, forming carbonic acid and lowering seawater pH.'),
  ('q37', 'Climate Science', 'What does ''carbon sequestration'' mean?', '["Burning carbon fuels more efficiently", "Capturing and storing CO₂ from the atmosphere", "Measuring the carbon content of soil", "Calculating a country''s total emissions"]'::jsonb, 1, 'Carbon sequestration captures atmospheric CO₂ in long-term sinks like forests, soils, or geological storage.'),
  ('q38', 'Climate Science', 'Which decade was the hottest on record as of 2024?', '["1990s", "2000s", "2010s", "2020s"]'::jsonb, 3, 'Global average temperatures reached unprecedented highs in the 2020s.'),
  ('q39', 'Climate Science', 'What is an ''emissions offset''?', '["A fine for exceeding emission limits", "A reduction in emissions elsewhere to compensate for your own", "A government subsidy for clean energy", "A type of renewable fuel"]'::jsonb, 1, 'Carbon offsets balance personal/corporate footprint by funding verified carbon reduction projects.'),
  ('q40', 'Climate Science', 'Approximately how many trees offset one tonne of CO₂ over 40 years?', '["1", "6", "50", "200"]'::jsonb, 2, 'It takes roughly 50 mature trees 40 years to absorb 1 metric tonne of CO₂.'),

  -- Nature & Sustainability (Q41 - Q50)
  ('q41', 'Nature', 'What percentage of the world''s biodiversity is found in tropical rainforests?', '["10%", "25%", "50%", "80%"]'::jsonb, 2, 'Tropical rainforests house over 50% of all terrestrial plant and animal species.'),
  ('q42', 'Nature', 'What is ''fast fashion'' primarily criticised for environmentally?', '["Using only synthetic dyes", "High volume production leading to massive textile waste and carbon emissions", "Making clothing too expensive", "Clothes that wear out too quickly"]'::jsonb, 1, 'Fast fashion drives high resource consumption, microplastic pollution, and landfill waste.'),
  ('q43', 'Nature', 'Plastic takes approximately how long to decompose in landfill?', '["10–20 years", "50–100 years", "200–500 years", "Thousands of years"]'::jsonb, 2, 'Standard synthetic plastics take 200 to 500 years to break down in landfills.'),
  ('q44', 'Nature', 'What is the circular economy?', '["An economy focused on circular trade routes", "A system designed to eliminate waste by keeping materials in use as long as possible", "A stock market cycle theory", "A farming technique that rotates crops in a circle"]'::jsonb, 1, 'Circular economies design out waste through continuous reuse, repair, remanufacturing, and recycling.'),
  ('q45', 'Nature', 'The most effective way to reduce your personal water footprint is:', '["Taking shorter showers", "Drinking only bottled water", "Reducing consumption of meat and dairy", "Installing a water butt"]'::jsonb, 2, 'Agricultural water for animal feed dominates virtual water footprints (1 kg beef requires 15,000L water).'),
  ('q46', 'Nature', 'What does ''biodegradable'' mean?', '["Can be recycled into new products", "Breaks down naturally by microorganisms without leaving toxic residue", "Made from plant-based materials", "Produces no greenhouse gases during production"]'::jsonb, 1, 'Biodegradable items decompose back into natural elements through biological action.'),
  ('q47', 'Nature', 'Which human activity is the leading driver of deforestation globally?', '["Urban expansion", "Mining and oil extraction", "Agricultural land clearance for livestock and crops", "Paper production"]'::jsonb, 2, 'Forest clearance for cattle ranching, soy, and palm oil accounts for ~80% of global deforestation.'),
  ('q48', 'Nature', 'What is ''greenwashing''?', '["Painting buildings green to reflect sunlight", "Marketing that exaggerates or falsely claims a product''s environmental benefits", "Washing clothing at low temperatures", "A government policy to tax high-emission products"]'::jsonb, 1, 'Greenwashing tricks consumers into believing a company or product is eco-friendly when it is not.'),
  ('q49', 'Nature', 'Composting organic waste helps the environment primarily by:', '["Creating plastic alternatives", "Returning nutrients to soil and reducing methane from landfill", "Producing clean energy", "Purifying water sources"]'::jsonb, 1, 'Composting diverts organics from anaerobic landfills, enriching soils without synthetic fertilizers.'),
  ('q50', 'Nature', 'Which best describes ''sustainable development''?', '["Development using as many resources as possible now", "Development that meets today''s needs without compromising future generations'' ability to meet theirs", "Development exclusively in rural areas", "Development funded by environmental charities"]'::jsonb, 1, 'Defined by the UN Brundtland Commission as meeting present needs without compromising future generations.')
ON CONFLICT (id) DO UPDATE SET
  category = EXCLUDED.category,
  question = EXCLUDED.question,
  options = EXCLUDED.options,
  correct_index = EXCLUDED.correct_index,
  explanation = EXCLUDED.explanation;

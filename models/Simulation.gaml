/***
* Name: MyThesis
* Author: mpizi
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model MyThesis

global {
	
	
	
	
	date true_date <- #now;
	int year_missing <- true_date.year;
	int month_missing <- true_date.month;
	int day_missing <- true_date.day;
	int hour_missing <- true_date.hour;
	int minute_missing <- true_date.minute;
	date starting_date <- date([year_missing,month_missing,day_missing,hour_missing,minute_missing,0]); //[Year, Month, Day, Hour, Minute, Sec]

	//GIS Input//
	//map used to filter the object to build from the OSM file according to attributes. for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
	map filtering <- (["highway"::["primary", "secondary", "tertiary", "motorway", "living_street","residential", "unclassified"], "building"::["yes"]]);
	
	//OSM file to load
	file<geometry> osmfile <-  file<geometry>(osm_file("../includes/carcelBabahoyo.osm", filtering))  ;
	
	//compute the size of the environment from the envelope of the OSM file
	geometry shape <- envelope(osmfile);
	
	float step <- 1 #mn; //every step is defined as 1 minute
	
	
	int nb_people <- 2000; //number of people in the simulation
	int nb_missing <- 5; //number of missing people (It will always be 1 in this simulation)
	int missing -> {length(missing_person)};
	int days_that_is_missing update: int(time / #day);
	int hours_that_is_missing update: int(time / #hour) mod 24;
	int minutes_that_is_missing update: int(time / #minute) mod 60;
	int current_hour <- starting_date.hour update: current_date.hour; //the current hour of the simulation
	int current_min <- starting_date.minute update: current_date.minute; //the current minute
	
	
	//variables conserning the times that people go and leave work respectively
	int min_work_start <- 7;
	int max_work_start <- 9;
	int min_work_end <- 16; 
	int max_work_end <- 18;
	
	//variables concerning the missing person
	int time_to_rest <- 3;
	
	//variables concerning the speed that the agents are traveling. Measured in km/h
	float min_walking_speed <- 3 #km / #h;
	float max_walking_speed <- 6 #km / #h;
	float min_driving_speed <- 5 #km / #h;
	float max_driving_speed <- 20 #km / #h;
	
	//variables concerning the speed that the missing person agent will be traveling. Measured in km/h
	float min_speed_missing <- 3.0 #km / #h;
	float max_speed_missing <- 5.0 #km / #h; 
	
	//variables concerning the probability of finding the missing person when near them
	float proba_find_walking <- 0.4;
	float proba_find_driving <- 0.2;
	float proba_find_resting <- 0.05;
	
	//variables for probabilistic location of missing person
	point Point_of_Interest1 <- nil;
	string Point_of_Interest1_name <- nil;
	point MP_Starting_Pos <- nil;
	string MP_Starting_Pos_name <- nil;
	
	int times_found<- 0;
	int times_found_walking <- 0;
	int times_found_driving <- 0;
	int times_found_resting <- 0;
	int close_call <-0;
	
	//bool variable for mp resting
	//When missing person is resting it is unlikely that they will be found
	bool m_p_resting<-true;
	
	graph the_graph; //initialize the graph that the agents will be moving on
	
	list missing_agents -> missing_person.population;
	agent the_missing_agent -> missing_agents at 0;
	
	float destroy <- 0.02; // burden on road if people agent moves through it
	
	float demographic_driving <- 0.0;
	float demographic_walking <- 0.0;
	bool demographic_bool;
	
	bool a_boolean_to_enable_parameters1 <- false;
	bool a_boolean_to_enable_parameters2 <- false;
	bool a_boolean_to_enable_parameters3 <- false;	
	bool a_boolean_to_enable_parameters4 <- false;
	
	bool is_batch <- false;

	
	init {
		
		if(demographic_driving != 0.0 or demographic_walking != 0.0) {
			demographic_bool <- true;
			if(demographic_driving = 0.0) {
				demographic_driving <- 100 - demographic_walking;
			}
			else {
				demographic_walking <- 100 - demographic_driving;
			}
		}
		else {demographic_bool <- false;}
		
		//possibility to load all of the attibutes of the OSM data: for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
		create osm_agent from:osmfile with: [highway_str::string(read("highway")), building_str::string(read("building"))];
		
		//from the created generic agents, creation of the selected agents
		ask osm_agent {
			if (length(shape.points) = 1 and highway_str != nil ) {
				create node_agent with: [shape ::shape, type:: highway_str]; 
			} else {
				if (highway_str != nil ) {
					create road with: [shape ::shape, type:: highway_str];
				} else if (building_str != nil){
					create building with: [shape ::shape];
				}  
			}
			//do the generic agent die
			do die;
		}
		
		
        //map<road,float> weights_map <- road as_map (each:: (each.destruction_coeff * each.shape.perimeter));
        //the_graph <- as_edge_graph(road) with_weights weights_map; //create the graph initialized above as an edge graph with weights
		
		//graph without traffic:
		the_graph <- as_edge_graph(road); //create the graph initialized above as an edge graph
		
		
		//the function that creates the people agents
		create people number: nb_people {
			
			//define start and end work time that each agent will have.
			//these values are random so it will be different in each simulation
			start_work_hour <- min_work_start + rnd (max_work_start - min_work_start) ;
			start_work_min <- rnd(0,60);
			end_work_hour <- min_work_end + rnd (max_work_end - min_work_end) ;
			end_work_min <- rnd(0,60);
			
			
			//define a living and a working place for each agent from the imported buildings
			living_place <- one_of(building) ;
			working_place <- one_of(building) ;
			
			//define specific spot inside building where agent resides or works
			home_spot <- any_location_in (living_place);
			work_spot <- any_location_in (working_place);

			if (demographic_bool){
				if(flip(demographic_driving/100)) {
					//write("local demo driving = true");
					local_demo_driving <- true;
				}
				else {
					//write("local demo walking = true");
					local_demo_driving <- false;
				}
			}
			//distance <- 1.5 * (living_place distance_to working_place);
			//small_distance <- distance < 1 #km;
			//if (small_distance) {walking_bool <- true;}
			//else {driving_bool <- true;}
   	
			//depending on the starting time of the simulation, the agent's starting location is either their
			//home or their workplace. Depending on where they are, the objective will either be working or resting.
			//write(current_hour);
			if((current_hour > start_work_hour and current_hour < end_work_hour) or (current_hour = start_work_hour and current_min > start_work_min) or 
				(current_hour = end_work_hour and current_min < end_work_min))
			{
				//write("LOCATION WORK"); 
				objective <- "working";
				location <- work_spot;
			}
			else {
				//write("LOCATION HOME"); 
				objective <- "resting";
				location <- home_spot;
			}
			
			driving_bool <- false;
			walking_bool <- false;			
		}
		
		//the function that creates the missing person agent
		create missing_person number: nb_missing {

			speed <- min_speed_missing + rnd (max_speed_missing- min_speed_missing) ;		
			
			
			if (MP_Starting_Pos_name != nil){
				ask building.population {
					if (name = MP_Starting_Pos_name) {
						MP_Starting_Pos <- location;
						write "Starting Position Coordinates";
						write MP_Starting_Pos;
						myself.living_place <- self;
						myself.input_flag <- true;
						self.color <- #maroon;
					}
					
				} 
				
				if(!input_flag) {
					write "Wrong Input Starting Position";
					living_place <- one_of(building) ;
					location <- any_location_in (living_place);
				}
				else {
					location <- MP_Starting_Pos;
				}
				
			}
			else{
				living_place <- one_of(building) ;
				location <- any_location_in (living_place); 
			}
			objective <- "running";
			
			
			if(Point_of_Interest1_name != nil) { 
				ask building.population {
					if (name = Point_of_Interest1_name) {
						Point_of_Interest1 <- location;
						write Point_of_Interest1;
						myself.input_flag <- true;
						self.color <- #gamablue;
					}
					
					/*if(!myself.input_flag) {
						write "Wrong Input PoI, no PoI added";
						//Point_of_Interest1_name <- nil;
						
					}*/
				} 
			}
		}
		
	}

//the following stops the simulation when the missing person is found
	reflex stop_simulation when: times_found = nb_missing {
		do pause;
	}
/* 	
	reflex update_graph{
        map<road,float> weights_map <- road as_map (each:: (each.destruction_coeff * each.shape.perimeter));
        the_graph <- the_graph with_weights weights_map;
     }*/
}


species osm_agent {
	string highway_str;
	string building_str;
} 

species node_agent {
	string type;
	aspect default { 
		draw square(3) color: #red ;
	}
} 

//define the building species
species building {
	string type; 
	rgb color <- #gray  ; //the color of each building
	
	aspect base {
		draw shape color: color ;
	}
}

//define the road species
species road  {
	string type; 
	//rgb color <- #black ; //the color of each road
	
	//we will simulate traffeic with road_destruction
	//float destruction_coeff <- 1.0 max 2.0;
    //int colorValue <- int(255*(destruction_coeff - 1)) update: int(255*(destruction_coeff - 1));
    rgb color <- #gamagreen;
	
	aspect base {
		draw shape color: color ;
	}
}


//define the missing_person species
species missing_person skills:[moving] {

	bool is_missing <- true;
	
	rgb color <- #maroon;

	building living_place <- nil ;
	//PoI.type <-  Point_of_Interest1_name;
	string objective <- "running" ; 
	point the_target <- nil ;
	int arrived <- 0;
	bool input_flag <- false;
	
	
		
	list people_nearby <- agents_at_distance(1); // people_nearby equals all the agents (excluding the caller) which distance to the caller is lower than 1
	
	int nb_of_agents_nearby -> {length(people_nearby)};
	
	
	//this reflex sets the target of the missing person to either a random building or a number of Points of Interest
	reflex run when: objective = "running" and the_target = nil {
		
		if(Point_of_Interest1 != nil and flip(0.4)){
			the_target <- Point_of_Interest1;
		}
		else {
			the_target <- point(one_of(building));  // casted one_of(building) to point type!!! one_of(the_graph.vertices);
		}
		arrived <- current_hour;
	}		

	reflex get_some_rest when: objective = "resting" and (current_hour = (arrived + time_to_rest)mod 24) {
		//write "HEY";
		objective <- "running";
		m_p_resting <- false;
		
		
	}
	
	//this reflex defines how the missing person moves 
	reflex move when: the_target != nil {
		do goto target: the_target on: the_graph ; 
		if the_target = location {
			the_target <- nil ;
			objective <- "resting";
			arrived <- current_hour;
			m_p_resting <- true;
		}
	}

	reflex encontrar when: is_missing = false {
		do die;
	}
	
	//the visualisation of the missing person on the graph
	aspect base {
		draw circle(100) color: color border: #black;
	}
	
}


//define the people species
species people skills:[moving] {
	
	rgb color <- #teal;
	
	building living_place <- nil ;
	building working_place <- nil ;
	int start_work_hour;
	int start_work_min;
	int end_work_hour;
	int end_work_min;
	
	bool small_distance;
	float distance;
	bool driving_bool <- nil;
	bool walking_bool <- nil;
	
	string objective ; 
	point the_target <- nil ;
	point work_spot <- nil;
	point home_spot <- nil;
	
	bool local_demo_driving;
		
	//this reflex sets the target when it's time to work and changes the objective of the agent to working
	reflex time_to_work when: current_hour = start_work_hour and current_min = start_work_min and objective = "resting"{
		objective <- "working" ;
		the_target <- work_spot;
		distance <- 1.5 * (living_place distance_to working_place);
		small_distance <- distance < 1 #km;		
		if(demographic_bool){
			if(local_demo_driving){driving_bool <- true;}
			else {walking_bool <- true;}
		}
		else{
			if(small_distance) {walking_bool <- true;}
			else {driving_bool<-true;}
		}		
		
	}
		
	//this reflex sets the target when it's time to go home and changes the objective of the agent to resting
	reflex time_to_go_home when: current_hour = end_work_hour and current_min = end_work_min and objective = "working"{
		objective <- "resting" ;
		the_target <- home_spot; 
		distance <- 1.5 * (living_place distance_to working_place);
		small_distance <- distance < 1 #km;
		if(demographic_bool){
			if(local_demo_driving){driving_bool <- true;}
			else {walking_bool <- true;}
		}
		else{
			if(small_distance) {walking_bool <- true;}
			else {driving_bool<-true;}
		}
		
	} 				
	
	//this reflex defines the probabilistic model by which the agent is found
	//in any of three states: 
	//when the People Agent is a.walking, b.driving, c.resting
	reflex missing_person_nearby when: agents_at_distance(4) contains_any missing_person {
		if(walking_bool){
			close_call<-close_call+1;
			write "Walking and near " + self;
			if(flip(proba_find_walking)){
				ask(missing_person at_distance(5)) {
					times_found <- times_found + 1;
					times_found_walking <- times_found_walking + 1;
					write "Niño encontrado " + self;
					is_missing <- false;				
				}
				write "Took a walk and stars aligned, FOUND by " + self +" Times Found " + times_found;
			}
		}
		else if(driving_bool){
			close_call<-close_call+1;
			write ("Driving and near" + self);
			if(flip(proba_find_driving)){
				ask(missing_person at_distance(5)) {
					times_found <- times_found + 1;
					times_found_driving <- times_found_driving + 1;
					write "Niño encontrado " + self;
					is_missing <- false;	
				}
				write "Prayers to driving gods helped, FOUND by " + self +" Times Found " + times_found;
			}
		}
		else {
			//write "Resting inside building Phase and Near";
			if(flip(proba_find_resting) and m_p_resting = false){
				ask(missing_person at_distance(5)) {
					close_call<-close_call+1;
					times_found <- times_found + 1;
					times_found_resting <- times_found_resting + 1;
					write "Niño encontrado " + self;	
					is_missing <- false;
				}
				write "Quarantine is King, FOUND by " +self +" Times Found " +times_found;
			}
		}
		
	}
	
	reflex walk when: (the_target !=nil and walking_bool){
		//boolean indicator initialization
		driving_bool <- false;
		speed <- min_walking_speed + rnd (max_walking_speed - min_walking_speed) ;
		path path_followed <- goto(target: the_target, on:the_graph, return_path: true);
    	list<geometry> segments <- path_followed.segments;
    	loop line over: segments {
        	float dist <- line.perimeter;
    	}
		if the_target = location {
			the_target <- nil; 
			//boolen indicator returning to default
			//write "Walking boolen indicator returning to default";
			walking_bool <- false;
		}
		
	
	}
	
	reflex drive when: (the_target !=nil and driving_bool){
		//boolean indicator initialization
		speed <- min_driving_speed + rnd (max_driving_speed - min_driving_speed) ;
		path path_followed <- goto(target: the_target, on:the_graph, return_path: true);
    	list<geometry> segments <- path_followed.segments;
    	loop line over: segments {
        	float dist <- line.perimeter;
    	}
		if the_target = location {
			the_target <- nil ;
			//write "Driving boolen indicator returning to default";
			//boolen indicator returning to default
			driving_bool <- false;
		}
		
	}
	
	//the visualisation of the missing person on the graph
	aspect base {
		draw circle(10) color: color border: #black;
	}
}


experiment find_missing_person type: gui {
	parameter "Simulation Map (type: .osm)" var: osmfile category: "GIS" ;
	
	//Determines number of people agents in simulation using globla var nb_people
	parameter "Number of people agents" var: nb_people category: "GIS" ;
	
	parameter "Time for missing person to rest" var: time_to_rest category: "Missing_Person" ;
	parameter "Probability of finding ms if walking" var: proba_find_walking category: "Probabilities" min: 0.01 max: 1.0;
	parameter "Probability of finding ms if driving" var: proba_find_driving category: "Probabilities" min: 0.01 max: 1.0;
	parameter "Probability of finding ms while resting" var: proba_find_resting category: "Probabilities" min: 0.01 max: 1.0;
	//parameter "PoInterest for missing Person" var: Point_of_Interest1 category: "Missing_Person";
	parameter "PoI building name" var: Point_of_Interest1_name category: "Missing_Person";
	parameter "Starting Position" var:  MP_Starting_Pos_name category: "Missing_Person";
	
	// Category: interactive enable
	// In the following, when a_boolean_to_enable_parameters1 ορ 2 is true, it enables the corresponding parameters 
	parameter "Start Time" category: "Activate Extended Parameters" var:a_boolean_to_enable_parameters1 enables: [year_missing, month_missing, day_missing, hour_missing, minute_missing];
	parameter "Demographics" category: "Activate Extended Parameters" var: a_boolean_to_enable_parameters2 enables: [demographic_driving,demographic_walking];
	parameter "People" category:"Activate Extended Parameters" var:a_boolean_to_enable_parameters3 enables: [min_work_start, max_work_start,
		 min_work_end, max_work_end, min_walking_speed, max_walking_speed, min_driving_speed, max_driving_speed];
	parameter "Missing Person" category:"Activate Extended Parameters" var:a_boolean_to_enable_parameters4 enables: [min_speed_missing, max_speed_missing ];
	
	//Start Time Activatable Parameters
	parameter "Year" var: year_missing category: "Start Time";
	parameter "Month" var: month_missing category: "Start Time";
	parameter "Day" var: day_missing category: "Start Time";
	parameter "Hour" var: hour_missing category: "Start Time";
	parameter "Minute" var: minute_missing category: "Start Time";
	
	//Demographic Data Activatable Parameters
	parameter "Drivers in Area (%) (Fill only one)" var: demographic_driving category: "Demographics";
	parameter "Walkers in Area (%) (Fill only one)" var: demographic_walking category: "Demographics";
	
	//People Activatable Parameters
	parameter "Earliest hour to start work"  category: "People" var: min_work_start min: 2 max: 8 step: 0.5;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
   	parameter "minimum speed" var: min_walking_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximum speed" var: max_walking_speed category: "People" max: 50 #km/#h;
	parameter "minimum speed" var: min_driving_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximum speed" var: max_driving_speed category: "People" max: 50 #km/#h;
	
	//Missing Person Activatable Parameters
	parameter "minimum speed for missing person" var: min_speed_missing category: "Missing_Person Ext" min: 0.1 #km/#h ;
	parameter "maximum speed for missing person" var: max_speed_missing category: "Missing_Person Ext" max: 50 #km/#h;
	
	//TODO
	parameter "Value of destruction when a people agent takes a road" var: destroy category: "Road" ;
	
	output {
		
		
		
		display chart_display refresh:every(1#cycles) {
			chart "People Status" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
                data "Working" value: people count (each.objective="working") color: #magenta ;
                data "Resting" value: people count (each.objective="resting") color: #blue ;
            }
            chart "Finding Missing Person" type: series  size: {1, 0.5} position: {0,0} {
                data "Times missing person was found" value: times_found  color: #red;
                data "Times missing person was close to being found" value: close_call color: #green;
            }
    
            
        }
        
        display city_display type: opengl {
			
			// refresh is useful in cases of not moving agents, but here for some 
			//reason it messes with the relative positions of agents		
			species building aspect: base; //refresh: false;
			species road aspect: base; // refresh: false;
			species missing_person aspect: base ;
			species people aspect: base;	
		}
       
        monitor "Days Missing" value: days_that_is_missing;
        monitor "Hours Missing" value: hours_that_is_missing;
        monitor "Minutes Missing" value: minutes_that_is_missing;
        monitor "Current Date" value: current_date;
        monitor "Close Calls" value: close_call;
        monitor "Times Found" value: times_found;
        monitor "Times Found Walking" value: times_found_walking;
        monitor "Times Found Driving" value: times_found_driving;
        monitor "Times Found Resting" value: times_found_resting;
        
	}
}

//20000 minutes is 13.88 days
experiment Batch_Optimization_No_Times_Found type: batch repeat: 2 keep_seed: true until: ( (time / #day) > 4) {
	parameter "Number of People in Area" var: nb_people min:800 max:1000 step: 20;
	//parameter "Probability of finding ms if walking" var: proba_find_walking category: "Probabilities" min: 0.01 max: 1.0 step: 0.1;
	//parameter "Probability of finding ms if driving" var: proba_find_driving category: "Probabilities" min: 0.01 max: 1.0 step: 0.1;
	//parameter "Probability of finding ms while resting" var: proba_find_resting category: "Probabilities" min: 0.01 max: 1.0 step: 0.1;
  	//parameter "Batch mode:" var: is_batch <- true;
   //,proba_find_walking,proba_find_driving,proba_find_resting  //2880
   
    //method exhaustive maximize: times_found;
    method tabu maximize: times_found iter_max: 10 tabu_list_size: 3;
    
    
    reflex save_results_explo {
        ask simulations {
            save [int(self),nb_people, self.times_found, self.times_found_walking, self.times_found_driving, self.times_found_resting] 
                   to: "../results_no_times.csv" type: "csv" rewrite: (int(self) = 0) ? true : false header: true;
        }        
    }
}

experiment Batch_Optimization_First_Time type:batch repeat: 2 keep_seed: true until: ( times_found = 1 ) {
	parameter "Number of People in Area" var: nb_people min:800 max:1000 step: 20;
   
    //method exhaustive maximize: times_found;
    method tabu maximize: times_found iter_max: 10 tabu_list_size: 3;
    
    reflex save_results_explo {
        ask simulations {
            save [int(self),nb_people, (time / #day), (time / #minute) ] 
                   to: "../results_first_time_mp.csv" type: "csv" rewrite: (int(self) = 0) ? true : false header: true;
        }        
    }
}
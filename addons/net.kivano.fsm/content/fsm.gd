tool
extends Node
##################################### README  ###############################
# 
# * Exported Variables which are intended to be used by users:
#
#     NodePath path2LogicRoot: states usually perform logic based on variables in
#         some external node, like 'Enemy'. This variable usually points to this node. 
#         It dont have any other purpose other than to be available for child states.
#
#     bool onlyActiveStateOnTheScene: if this is true, then only active state is present
#         on scene tree. It might be handy if states have visual representation
#
#     bool transitionsHardcodedInStates: if this is true, then State.computeNextState() 
#         must be ovverriden to always return next state name (it can return self.get_name())
#
#     bool initManually: #you can set this to true to set export vars in runtime from code,
#         before you will be able to use this FSM you will need to run init() function. 
#         Run init() only after setting exported variables.
#
#     string Initial state: you can choose from this list with which state FSM should start.
#
#     int updateMode: if set to manual, then it's up to you to update this FSM. Take a look 
#         at update(inDeltaTime) function.
#
########## 
# * Exported variables that are editor helpers:
#
#      Subdirectory for states: you can set name of directory which will be automatically 
#          created to hold all states for this FSM
#
#      Create state with name: when you enter and accept name for a state it will be 
#          immediatelly created and added to scene tree as a child of current FSM
#          This state will have an unique script in which you can implement state logic.
#
#
###########
# * Functions that are intended to be used by users:
#
#     getStateID(): return name of current state
#
#     getState(): return node with current state  
#
#     changeStateTo(inNewStateID): can be used to change state. 
#        Usually dont need to be used when state transitions are 
#        hardcoded into states( transitionsHardcodedInStates = true)
#      
#     stateTime(): returns how long current state is active
#
#     update(inDeltaTime): update FSM to update current state. Should be
#        used in every game tick, but should use it only if you are using 
#        updateMode="Manual".


##################################################################################
#########                       Signals definitions                      #########
##################################################################################
signal stateChanged(newStateID, oldStateID);

##################################################################################
#####  Variables (Constants, Export Variables, Node Vars, Normal variables)  #####
######################### var myvar setget myvar_set,myvar_get ###################
const UPDATE_MODE_MANUAL = 0;
const UPDATE_MODE_PROCESS = 1;
const UPDATE_MODE_FIXED_PROCESS = 2;

export (NodePath) var path2LogicRoot = NodePath(".."); 
export (bool) var onlyActiveStateOnTheScene = true setget setOnlyActiveStateOnScene; 
export (bool) var transitionsHardcodedInStates = false; 
export (bool) var initManually = false; 
export (int, "Manual", "Process", "Fixed") var updateMode = UPDATE_MODE_MANUAL;

var initStateID = "" setget setInitState; #id of initial state for this fsm (id is the same as state node name)
var currentStateID = initStateID;
var currentState = null
var states = {"":""};
var stateTime = 0;

##################################################################################
#########                          Init code                             #########
##################################################################################
func _ready():
	if(initManually):
		return;
	init();

func init():
	#
	if(get_tree().is_editor_hint()): return;
	if(get_child_count()==0): return;
	
	#
	ensureInitStateIdIsSet();
	
	#
	var states2Add = get_children();
	for state2Add in states2Add:
		if(state2Add extends preload("FSMState.gd")):
			states[state2Add.get_name()] = state2Add;
			if(!get_tree().is_editor_hint()):
				state2Add.logicRoot = get_node(path2LogicRoot);
				state2Add.fsm = self;

	#
	if(onlyActiveStateOnTheScene):
		var statesKeys = states.keys();
		for stateKey in statesKeys:
			if(stateKey!=initStateID):
				remove_child(get_node(stateKey));

	#
	if(initStateID!=""):
		currentState = states[initStateID];
		currentStateID = initStateID;
	else:
		currentState = get_children()[0];
		currentStateID = currentState.get_name();
	
	#
	currentState.enter();
	
	#
	initUpdateMode();


func initUpdateMode():
	if(updateMode==UPDATE_MODE_MANUAL): return;
	elif(updateMode==UPDATE_MODE_PROCESS): set_process(true);
	elif(updateMode==UPDATE_MODE_FIXED_PROCESS): set_fixed_process(true);

func ensureInitStateIdIsSet():
	if(initStateID == ""): 
		initStateID = get_child(0).get_name();

##################################################################################
#########                       Getters and Setters                      #########
##################################################################################
func stateTime():
	return stateTime;

func getStateID():
	return currentStateID;

func getState():
	return currentState;

func changeStateTo(inNewStateID):
	if(currentStateID!=inNewStateID):
		setState(inNewStateID);
	
func setState(inStateID):
	
	#
	var prevStateID = currentStateID;
	currentState.exit(inStateID);
	
	#
	if(onlyActiveStateOnTheScene):
		remove_child(currentState);
		add_child(states[inStateID]);
		
	#
	currentState = states[inStateID];
	currentState.enter(prevStateID);
	currentStateID = currentState.get_name()
	stateTime = 0.0;
	
	#
	emit_signal("stateChanged", currentStateID, prevStateID);


#### setters bellow are used by tool
#######
func setInitState(inInitState):
	initStateID = inInitState;
	if(is_inside_tree() && get_tree().is_editor_hint() && onlyActiveStateOnTheScene):
		hideAllVisibleStatesExceptInitOne();

func setOnlyActiveStateOnScene(inVal):
	onlyActiveStateOnTheScene = inVal;
	if(is_inside_tree() && get_tree().is_editor_hint()):
		if(onlyActiveStateOnTheScene):
			hideAllVisibleStatesExceptInitOne();
		else:
			showAllVisibleStates();

##################################################################################
#########                         Public Methods                         #########
##################################################################################
func update(inDeltaTime):
	if(transitionsHardcodedInStates):
		var nextStateID = currentState.computeNextState();
		if(nextStateID!=currentStateID):
			setState(nextStateID);
	stateTime += inDeltaTime;
	return currentState.update(inDeltaTime);

#just an alias for update, for the cases when delta time dont have much sense
func perform():
	update(0);

#################################################################################
#########                    Implemented from ancestor                   #########
##################################################################################
func _process(delta):
	update(delta);

func _fixed_process(delta):
	update(delta);

####################################
###########################
############### TOOL / PLUGIN part
#############################
####################################
const INSP_INIT_STATE = "Initial state:";
const INSP_SUBDIR_4_STATES  = "Create new State/Subdirectory for states";
const INSP_CREATE_NEW_STATE = "Create new State/Create state with name:";


var additionalSubDirectory4States = "FSM";
var newStateName = "" setget createState;

func createState(inStateName):
	if (inStateName==null) || (inStateName.empty()) || has_node(inStateName): return;
	
	#
	var owner = get_owner();
	var dirPath = owner.get_filename().get_base_dir();

	#
	var dirMaker = Directory.new();
	if(additionalSubDirectory4States!=""): 
		dirPath = dirPath + "/" +additionalSubDirectory4States ;
		dirMaker.make_dir(dirPath);
	dirPath = dirPath + "/" + inStateName
	dirMaker.make_dir(dirPath);
	
	var scriptFilePath = dirPath + "/" + inStateName + ".gd";
	var sceneFilePath = dirPath + "/" + inStateName + ".tscn";
	
	#
	var saveGameFile = File.new();
	saveGameFile.open(scriptFilePath, File.WRITE);
	saveGameFile.store_string(load("res://addons/net.kivano.fsm/content/StateTemplate.gd").get_source_code()); 
	saveGameFile.close();
	var script = load(scriptFilePath);
	
	#
	var scnStateNode = Node.new();
	scnStateNode.set_script(script);
	scnStateNode.set_name(inStateName);
	var packedScn = PackedScene.new();
	packedScn.pack(scnStateNode);
	ResourceSaver.save(sceneFilePath, packedScn);
	
	var scn2Add = load(sceneFilePath).instance();
	add_child(scn2Add)
	scn2Add.set_owner(get_tree().get_edited_scene_root());

func _get_property_list():
	var currentStatesList = get_children();
	var statesListString = "";
	for state in currentStatesList:
		statesListString = statesListString + state.get_name() + ",";
	statesListString.erase(statesListString.length()-1,1)
	
	return [
		{
            "hint": PROPERTY_HINT_ENUM,
            "usage": PROPERTY_USAGE_DEFAULT,
 			"hint_string":statesListString,
            "name": INSP_INIT_STATE,
            "type": TYPE_STRING
        },
        {
            "hint": PROPERTY_HINT_NONE,
            "usage": PROPERTY_USAGE_DEFAULT,
            "name": INSP_SUBDIR_4_STATES,
            "type": TYPE_STRING
        },
		{
            "hint": PROPERTY_HINT_NONE,
            "usage": PROPERTY_USAGE_DEFAULT,
            "name": INSP_CREATE_NEW_STATE,
            "type": TYPE_STRING
        }
    ];
func _get(property):
	if(property == INSP_SUBDIR_4_STATES):
		return additionalSubDirectory4States;        
	elif(property==INSP_INIT_STATE):
		return initStateID;

func _set(property, value):
	if(property == INSP_SUBDIR_4_STATES):
		additionalSubDirectory4States = value;
		return true;
	elif(property == INSP_CREATE_NEW_STATE):
		createState(value);
		return false;
	elif(property==INSP_INIT_STATE):
		setInitState(value);
		return true

#### visibility of states
#######
func showAllVisibleStates():
	callMethodInStatesAndAllDirectChilds("show");
func hideAllVisibleStatesExceptInitOne():
	callMethodInStatesAndAllDirectChilds("hide");

func callMethodInStatesAndAllDirectChilds(inMethodName):
	var states = get_children();
	for state in states:
		if(state.get_name()==initStateID): 
			showStateOrItsDirectChilds(state);
			continue;
		if(state.has_method(inMethodName)): 
			state.call(inMethodName);
			continue;
		var stateChilds = state.get_children();
		for stateChild in stateChilds:
			if(stateChild.has_method(inMethodName)): stateChild.call(inMethodName);

func showStateOrItsDirectChilds(inState):
	if(inState.has_method("show")): 
		inState.show;
	else:
		var stateChilds = inState.get_children();
		for stateChild in stateChilds:
			if(stateChild.has_method("show")): stateChild.show();

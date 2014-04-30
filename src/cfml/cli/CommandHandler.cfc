/**
 * Command handler
 * @author Denny Valliant
 **/
component output='false' persistent='false' {

	instance = {
		shell = '',
		commands = {},
		commandAliases = {},
		namespaceHelp = {},
		thisdir = getDirectoryFromPath(getMetadata(this).path),
		System = createObject('java', 'java.lang.System')
	};
	
	
	instance.rootCommandDirectory = instance.thisdir & '/commands';
	
	// Convenience value
	cr = instance.System.getProperty('line.separator');

	/**
	 * constructor
	 * @shell.hint shell this command handler is attached to
	 **/
	function init(required shell) {
		instance.shell = shell;
		reader = instance.shell.getReader();
        var completors = createObject('java','java.util.LinkedList');
        instance.parser = new parser();
		initCommands( instance.rootCommandDirectory, '' );
				
		var completor = createDynamicProxy(new Completor(this), ['jline.Completor']);
        reader.addCompletor(completor);
		return this;
	}

	/**
	 * initialize the commands. This will recursively call itself for subdirectories.
	 **/
	function initCommands( required commandDirectory, required commandPath ) {
		var varDirs = DirectoryList( path=commandDirectory, recurse=false, listInfo='query', sort='type desc, name asc' );
		for(var dir in varDirs){
			
			// For CFC files, process them as a command
			if( dir.type  == 'File' && listLast( dir.name, '.' ) == 'cfc' ) {
				loadCommand( dir.name, commandPath );
			// For folders, search them for commands
			// Temporary exclusion for 'home' dir in cfdistro
			} else if( dir.name != 'home' ) {
				initCommands( dir.directory & '\' & dir.name, listAppend( commandPath, dir.name, '.' ) );
			}
			
		}
		
	}

	/**
	 * load command CFC
	 * @cfc.hint CFC name that represents the command
	 * @commandPath.hint The relative dot-delimted path to the CFC starting in the commands dir
	 **/
	function loadCommand( CFC, commandPath ) {
		
		// Strip cfc extension from filename
		var CFCName = mid( CFC, 1, len( CFC ) - 4 );
		// Build CFC's path
		var fullCFCPath = 'commands.' & iif( len( commandPath ), de( commandPath & '.' ), '' ) & CFCName;
		 		
		// Create this command CFC
		var command = createObject( fullCFCPath );
		
		// Check and see if this CFC instance is a command and has a run() method
		if( !isInstanceOf( command, 'BaseCommand' ) || !structKeyExists( command, 'run' ) ) {
			return;
		}
	
		// Initialize the command
		command.init( instance.shell );
	
		// Mix in some metadata
		decorateCommand( command );
		
		// Add it to the command dictionary
		registerCommand( command, commandPath & '.' & CFCName );
		
		// Register the aliases
		for( var alias in command.$CommandBox.aliases ) {
			registerCommand( command, commandPath & '.' & trim(alias) );
		}
	}
	
	function decorateCommand( required command ) {
		// Grab its metadata
		var CFCMD = getMetadata( command );
		
		// Set up metadata struct
		var commandMD = {
			aliases = listToArray( CFCMD.aliases ?: '' ),
			parameters = [],
			hasHelp = false,
			hint = CFCMD.hint ?: '',
			originalName = CFCMD.name
		};
		
		// Check for help() method
		if( structKeyExists( command, 'help' ) ) {
			commandMD.hasHelp = true;
		}
		
		// Capture the command's parameters
		commandMD.parameters = getMetaData(command.run).parameters;
		
		// Inject metadata into command CFC
		command.$CommandBox = commandMD;
		
	}
	
	function registerCommand( required command, required commandPath ) {
		// Build bracketed string of command path to allow special characters
		var commandPathBracket = '';
		for( var item in listToArray( commandPath, '.' ) ) {
			commandPathBracket &= '["#item#"]';
		}
				
		// Register the command in our command dictionary
		evaluate( "instance.commands#commandPathBracket# = command" );
	}

	/**
	 * get help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	function help(String namespace='', String command='')  {
		if(namespace != '' && command == '') {
			if(!isNull(commands[''][namespace])) {
				command = namespace;
				namespace = '';
			} else if(!isNull(commandAliases[''][namespace])) {
				command = commandAliases[''][namespace];
				namespace = '';
			} else if (isNull(commands[namespace])) {
				instance.shell.printError({message:'No help found for #namespace#'});
				return '';
			}
		}
		var result = instance.shell.ansi('green','HELP #namespace# [command]') & cr;
		if(namespace == '' && command == '') {
			for(var commandName in commands['']) {
				var helpText = commands[''][commandName].hint;
				result &= chr(9) & instance.shell.ansi('cyan',commandName) & ' : ' & helpText & cr;
			}
			for(var ns in namespaceHelp) {
				var helpText = namespaceHelp[ns];
				result &= chr(9) & instance.shell.ansi('black,cyan_back',ns) & ' : ' & helpText & cr;
			}
		} else {
			if(!isNull(commands[namespace][command])) {
				result &= getCommandHelp(namespace,command);
			} else if (!isNull(commands[namespace])){
				var helpText = namespaceHelp[namespace];
				result &= chr(9) & instance.shell.ansi('cyan',namespace) & ' : ' & helpText & cr;
				for(var commandName in commands[namespace]) {
					var helpText = commands[namespace][commandName].hint;
					result &= chr(9) & instance.shell.ansi('cyan',commandName) & ' : ' & helpText & cr;
				}
			} else {
				instance.shell.printError({message:'No help found for #namespace# #command#'});
				return '';
			}
		}
		return result;
	}

	/**
	 * get command help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	private function getCommandHelp(String namespace='', String command='')  {
		var result ='';
		var metadata = commands[namespace][command];
		result &= chr(9) & instance.shell.ansi('cyan',command) & ' : ' & metadata.hint & cr;
		result &= chr(9) & instance.shell.ansi('magenta','Arguments') & cr;
		for(var param in metadata.parameters) {
			result &= chr(9);
			if(param.required)
				result &= instance.shell.ansi('red','required ');
			result &= param.type & ' ';
			result &= instance.shell.ansi('magenta',param.name);
			if(!isNull(param.default))
				result &= '=' & param.default & ' ';
			if(!isNull(param.hint))
				result &= ' (#param.hint#)';
		 	result &= cr;
		}
		return result;
	}

	/**
	 * run a command line
	 * @line.hint line to run
 	 **/
	function runCommandline(line) {
		// Turn the users input into an array of tokens
		var tokens = instance.parser.tokenizeInput( line );
		// Resolve the command they are wanting to run
		var commandInfo = resolveCommand( tokens );
		
		// If nothing was found, bail out here.
		if( !commandInfo.found ) {
			instance.shell.printError({message:'Command "#line#" cannot be resolved.  Please type "help" for assitance.'});
			return;
		}
		
		var parameterInfo = instance.parser.parseParameters( commandInfo.parameters );
				
		// Parameters need to be ALL positional or ALL named
		if( arrayLen( parameterInfo.positionalParameters ) && structCount( parameterInfo.namedParameters ) ) {
			instance.shell.printError({message:"Please don't mix named and positional parameters, it makes me dizzy."});
			return;
		}
		
		// These are the parameters declared by the command CFC
		var commandParams = commandInfo.commandReference.$CommandBox.parameters;
		
		// If we're using postitional params, convert them to named
		if( arrayLen( parameterInfo.positionalParameters ) ) {
			parameterInfo.namedParameters = convertToNamedParameters( parameterInfo.positionalParameters, commandParams );
		}
		
		// Make sure we have all required params. 
		parameterInfo.namedParameters = ensureRequiredParams( parameterInfo.namedParameters, commandParams );
				
		return commandInfo.commandReference[ 'run' ]( argumentCollection = parameterInfo.namedParameters );
		
	}


	/**
	 * Figure out what command to run based on the tokenized user input
 	 **/
	function resolveCommand( tokens ) {
		
		var cmds = instance.commands;
		
		var results = {
			commandString = '',
			commandReference = cmds,
			parameters = [],
			found = false
		};
		
		var lastHelpReference = '';
					
		// Check for a root help command
		if( structKeyExists( results.commandReference, 'help' ) && isObject( results.commandReference.help ) ) {
			lastHelpReference = results.commandReference.help;
		}
		
		for( var token in tokens ) {
			
			// If we hit a dead end, then quit looking
			if( !structKeyExists( results.commandReference, token ) ) {
				break;
			}
			
			// Move the pointer
			results.commandString = listAppend( results.commandString, token, '.' );
			results.commandReference = results.commandReference[ token ];
			
			// If we've reached a CFC, we're done
			if( isObject( results.commandReference ) ) {
				results.found = true;
				break;
			// If this is a folder, check and see if it has a "help" command
			} else {	
				if( structKeyExists( results.commandReference, 'help' ) && isObject( results.commandReference.help ) ) {
					lastHelpReference = results.commandReference.help;
				}
			}
			
			
		} // end for loop
		
		// If we found a command, carve the parameters off the end
		var commandLength = listLen( results.commandString, '.' );
		var tokensLength = arrayLen( tokens );
		if( results.found && commandLength < tokensLength ) {
			results.parameters = tokens.slice( commandLength+1 );			
		}
		
		// If we failed to match a command, but we did encounter a help command along the way, make that the new command
		if( !results.found && isObject( lastHelpReference ) ) {
			results.commandReference = lastHelpReference;
			results.found = true;
		}
		
		return results;
				
	}

	
	/**
	 * Match positional parameters up with their names 
 	 **/
	private function convertToNamedParameters( userPositionalParams, commandParams ) {
		var results = {};
		
		var i = 0;
		// For each param the user typed in
		for( var param in userPositionalParams ) {
			i++;
			// Figure out its name
			if( arrayLen( commandParams ) >= i ){
				results[ commandParams[i].name ] = param;
			// Extra user params just get assigned a name
			} else {
				results[ i ] = param;
			}
		}
		
		return results;		
	}


	/**
	 * Make sure we have all required params
 	 **/
	private function ensureRequiredparams( userNamedParams, commandParams ) {
		
		// For each command param
		for( var param in commandParams ) {
			// If it's required and hasn't been supplied...
			if( param.required && !structKeyExists( userNamedParams, param.name ) ) {
				// ... Ask the user
				var message = 'Enter #param.name#';
				if( structKeyExists( param, 'hint' ) ) {
					message &= ' (#param.hint#)';	
				}
				message &= ' : ';
           		var value = instance.shell.ask( message );
           		userNamedParams[ param.name ] = value;				
			}
		} // end for loop
		
		return userNamedParams;
	}


	/**
	 * return a list of base commands (includes namespaces)
 	 **/
	function listCommands() {
		return structKeyList( instance.commands );
	}

	/**
	 * return the command structure
 	 **/
	function getCommands() {
		return instance.commands;
	}


	/**
	 * return the shell
 	 **/
	function getShell() {
		return instance.shell;
	}
}
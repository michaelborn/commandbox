/**
 * This command will write a file, overwriting it if it exists. You can pipe content into it.
 * This comand is used for redirection when you type echo "text" > file.txt
 * .
 * fileWrite "My file contents" file.txt
 * .
 * echo "My file contents" | fileWrite file.txt
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=true {

	/**
	 * @contents.hint Contents to write to the file
	 * @file.hint File to write to
 	 **/
	function run( required contents='', required string file )  {
		
		// This will make the file path canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );

		// Clean out any ANI escape codes from the text
		arguments.contents = print.unansi( arguments.contents );

		// Write the file
		fileWrite( arguments.file, arguments.contents );
		
	}

}
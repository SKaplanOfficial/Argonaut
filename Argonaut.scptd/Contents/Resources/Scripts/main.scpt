#@osa-lang:AppleScript
(*
 * Created By: Stephen Kaplan
 * Created On: Sun Sep 10 19:55:41 EDT 2023
 *
 * Copyright © 2023 Stephen Kaplan
 *)

use AppleScript version "2.4"
use framework "Foundation"
use scripting additions

property args : {} -- The argument configurations. Includes status records once any checking handler has finished.
property globalHelpText : "" -- Script-level help text to display when users supply the --help or -h flag.
property allowPositionalArguments : true -- Whether to allow arguments to be specified by position only, without flags.
property shouldClearData : false -- Whether Argonaut needs to clear internal data before proceeding.
property errorMode : «constant !Aem*AeL» -- The strategy for handling errors.

(*
 * Help Text & General Info
 **********************)

(*
 * Returns an extended help string for the given argument.
 *)
on _generateDetailText(theArg)
	set newDetails to ""

	if theArg's «class Aacv» is missing value then
		if class of theArg's type class is list then
			set typesString to ""
			repeat with theType in theArg's type class
				set typesString to typesString & _typeToString(theType) & ", "
			end repeat
			set endIndex to (length of typesString) - 2
			set typesString to text 1 thru endIndex of typesString

			if "any" is in typesString then
				set newDetails to newDetails & "Accepts a value of any type. "
			else
				set newDetails to newDetails & "Expects a value of any of the following types: " & typesString & "."
			end if
		else
			set argType to _typeToString(theArg's type class)
			if argType is "any" then
				set newDetails to newDetails & "Accepts a value of any type. "
			else
				if argType is "URL" then
					set argType to "URL (fitting the form scheme://host, e.g. 'https://apple.com')"
				end if
				set newDetails to newDetails & "Expects a value of type " & argType & ". "
			end if
		end if
	else
		set valuesString to ""
		set valuesString to "Accepted values: "
		repeat with acceptedValue in theArg's «class Aacv»
			set acceptedValueString to acceptedValue
			if not _isInteger(acceptedValue) and not _isDecimal(acceptedValue) and not _isBoolean(acceptedValue) then
				set acceptedValueString to quoted form of acceptedValue
			end if
			if (acceptedValue as text) is (theArg's «class Agdv» as text) then
				set valuesString to valuesString & acceptedValueString & " (default), "
			else
				set valuesString to valuesString & acceptedValueString & ", "
			end if
		end repeat
		set endIndex to (length of valuesString) - 2
		set valuesString to (text 1 thru endIndex of valuesString) & ". "

		set newDetails to newDetails & valuesString
	end if

	if theArg's «class Agru» is true then
		set newDetails to newDetails & "Required. Failure to include this argument will raise an error."
	else
		if theArg's «class Agdv» is missing value then
			set newDetails to newDetails & "Optional. You can safely exclude this argument, but you might need/want to include it to carry out specific actions."
		else
			set defaultValueString to theArg's «class Agdv»
			if not _isInteger(defaultValueString) and not _isDecimal(defaultValueString) and not _isBoolean(defaultValueString) then
				set defaultValueString to quoted form of defaultValueString
			end if
			set newDetails to newDetails & "Optional. If you don't specify a value, the default value, " & defaultValueString & ", will be used."
		end if
	end if
	return newDetails
end _generateDetailText

(*
 * Returns a string that briefly summarizes the argument, its required type, expected values, etc.
 *)
on _generateHelpText(theArg)
	set newHelpText to ""
	if theArg's «class Aacv» is missing value then
		set typeString to ""
		if class of theArg's type class is list then
			repeat with theType in theArg's type class
				set typeString to typeString & _typeToString(theType) & ", "
			end repeat
			set endIndex to (length of typeString) - 2
			set typeString to text 1 thru endIndex of typeString
		else
			set typeString to _typeToString(theArg's type class)
		end if

		set newHelpText to newHelpText & "type: " & typeString & ", "

		if theArg's «class Agru» is true then
			set newHelpText to newHelpText & "required."
		else
			set newHelpText to newHelpText & "optional."
		end if
	else
		set valuesString to ""
		set valuesString to "values: "
		repeat with acceptedValue in theArg's «class Aacv»
			set acceptedValueString to acceptedValue
			if not _isInteger(acceptedValue) and not _isDecimal(acceptedValue) and not _isBoolean(acceptedValue) then
				set acceptedValueString to quoted form of acceptedValue
			end if
			if (acceptedValue as text) is (theArg's «class Agdv» as text) then
				set valuesString to valuesString & acceptedValueString & " (default), "
			else
				set valuesString to valuesString & acceptedValueString & ", "
			end if
		end repeat
		set endIndex to (length of valuesString) - 2
		set valuesString to (text 1 thru endIndex of valuesString) & ". "

		set newHelpText to newHelpText & valuesString

		if theArg's «class Agru» is true then
			set newHelpText to newHelpText & "Required."
		else
			set newHelpText to newHelpText & "Optional."
		end if
	end if
	return newHelpText
end _generateHelpText

(*
 * Returns help text describing an argument's dependencies. Checks to ensure the dependencies are valid argument names.
 *)
on _generateDependencyText(theArg, args, checkNames as boolean)
	set dependencyNames to {}
	if checkNames then
		set realArgNames to «event ©!Ag©!an»
		repeat with dependencyName in theArg's «class Agfd»
			if dependencyName is in realArgNames then
				copy dependencyName to end of dependencyNames
			end if
		end repeat
	else
		set dependencyNames to theArg's «class Agfd»
	end if

	if length of dependencyNames > 1 then
		set dependencyListText to ""
		repeat with dependencyName in dependencyNames
			set dependencyListText to dependencyListText & dependencyName & ", "
		end repeat
		set endIdx to (length of dependencyListText) - 2
		set dependencyListText to (text 1 thru endIdx of dependencyListText)
		return " To use this argument, you must also provided valid values for these arguments: " & dependencyListText & "."
	else if length of dependencyNames is 1 then
		return " To use this argument, you must also provided valid values for the '" & item 1 of dependencyNames & "' argument."
	end if
end _generateDependencyText

(*
 * Logs the global help text when the "help" argument is detected.
 *)
on _showGlobalHelpText(argName, theState, isValid)
	if theState is «constant !Aas*AsV» then
		log my globalHelpText
	end if
end _showGlobalHelpText

(*
 * Displays an error when a required argument is missing.
 *)
on _showMissingText(theArg, theState, theValue)
	_displayError("Error: Missing required argument '" & name of theArg & "'. Call the script again with the '--help' flag to see extended help, or use '--" & name of theArg & " help' to get help specific to this argument.")
end _showMissingText

(*
 * Displays help text for a specific argument.
 *)
on _showHelpText(theArg, theState, theValue, errorReason)
	if theState is «constant !Aas*AsI» and theValue as text is not "help" then
		set errorText to "Error: Invalid use of argument '" & name of theArg & "'. " & errorReason
		_displayError(errorText)
	end if
	log name of theArg & " - " & «class Agdt» of theArg & _generateDependencyText(theArg, my args, true)
end _showHelpText

(*
 * Raises or logs an error message depending on the configured error mode.
 *)
on _displayError(errorText)
	if my errorMode is «constant !Aem*AeR» then
		error errorText
	else
		log errorText
	end if
end _displayError

(*
 * Wraps the supplied handler in a script object so that it can be called via a standard interface.
 *)
on _wrapHandler(theHandler, handlerParams)
	if handlerParams is («class !ARp») then
		script ActionHandlerCaller
			property func : theHandler
			on execute(theArg, theState, theValue)
				if class of theHandler is script then
					theHandler's runAction(theArg, theState, theValue)
				else
					my func(theArg, theState, theValue)
				end if
			end execute
		end script
		return ActionHandlerCaller
	end if

	if handlerParams is «class !AVp» then
		script ValidatorHandlerCaller
			property func : theHandler
			on execute(argName, theValue)

				if class of theHandler is script then
					theHandler's validate(argName, theValue)
				else
					my func(argName, theValue)
				end if
			end execute
		end script
		return ValidatorHandlerCaller
	end if


	if handlerParams is «class !AHa» then
		script HandlerCaller
			property func : theHandler
			on execute(arglist, theSummary)
				if class of theHandler is script then
					theHandler's handle(arglist, theSummary)
				else
					my func(arglist, theSummary)
				end if
			end execute
		end script
		return HandlerCaller
	end if

	if handlerParams is «class !ACf» then
		script CustomFilterCaller
			property func : theHandler
			on execute(theArg)
				if class of theHandler is script then
					theHandler's passesFilter(theArg)
				else
					my func(theArg)
				end if
			end execute
		end script
		return CustomFilterCaller
	end if
end _wrapHandler

on «event ©!Ag©!ca» argumentName given «class !cat»:theType : «constant !Aat*AtA», «class !cva»:theValues : missing value, «class !cdv»:defaultValue : missing value, «class !caf»:theFlag : missing value, «class !cah»:theHelpText : "", «class !cad»:theDetails : "", «class !cvd»:theValidator : missing value, «class !caa»:theAction : missing value, «class !car»:isRequired : true, «class !cdd»:theDependencies : {}

	if my shouldClearData is true then
		set my args to {}
		set my shouldClearData to false
		set my allowPositionalArguments to true
	end if

	set dependencyNames to {}
	repeat with theDependency in theDependencies
		if class of theDependency is text then
			copy theDependency to end of dependencyNames
		else
			copy name of theDependency to end of dependencyNames
		end if
	end repeat

	set standardType to _standardizeType(theType)
	if theValues is not missing value and class of theValues is not list then
		set theValues to {theValues}
	else if theValues is not missing value and length of theValues is 0 then
		set theValues to missing value
	end if
	set pos to (length of my args) + 1
	set newArgument to {name:argumentName, «class Agru»:isRequired, type class:standardType, «class Aacv»:theValues, «class Agdv»:defaultValue, «class Agfl»:theFlag, «class Agps»:pos, «class Aght»:theHelpText, «class Agdt»:theDetails, «class Agav»:missing value, «class Agac»:missing value, «class Agfd»:dependencyNames, «class Agst»:missing value}

	if theHelpText is "" then set newArgument's «class Aght» to _generateHelpText(newArgument)
	if theDetails is "" then set newArgument's «class Agdt» to _generateDetailText(newArgument)

	if theAction is not missing value then
		set newArgument's «class Agac» to _wrapHandler(theAction, «class !ARp»)
	end if

	if theValidator is not missing value then
		set newArgument's «class Agav» to _wrapHandler(theValidator, «class !AVp»)
	end if

	copy newArgument to end of my args
	return newArgument
end «event ©!Ag©!ca»

on «event ©!Ag©!an» theArgs : missing value
	set theNames to {}
	if theArgs is missing value or class of theArgs is script then set theArgs to my args
	repeat with theArg in theArgs
		copy theArg's name to end of theNames
	end repeat
	return theNames
end «event ©!Ag©!an»

on «event ©!Ag©!lS»
	return my args
end «event ©!Ag©!lS»

on «event ©!Ag©!Fi» theArgs : missing value given «class !cfs»:theState : missing value, «class !cft»:theType : missing value, «class !cfr»:isRequired : missing value, «class !cfv»:hasValue : missing value, «class !cvf»:theCustomFilter : missing value
	if theArgs is missing value or class of theArgs is script then set theArgs to my args
	set filteredArgs to {}

	set customFilter to missing value
	if theCustomFilter is not missing value then
		set customFilter to _wrapHandler(theCustomFilter, «class !ACf»)
	end if
	repeat with theArg in theArgs
		set include to true
		if theState is not missing value then
			if theArg's «class Agst» is missing value then
				set include to false
			else
				if theArg's «class Agst»'s «class Agss» is not theState then set include to false
			end if
		end if

		if theType is not missing value then
			set anyListType to {«constant !Aat*AtL», list}
			if class of theArg's type class is list then
				set include to false
				repeat with argTypeOption in theArg's type class
					if class of theType is list then
						repeat with filterTypeOption in theType
							if (filterTypeOption is not in anyListType and _typeToString(argTypeOption) as text is _typeToString(filterTypeOption) as text) or (filterTypeOption is in anyListType and _typeList(argTypeOption)) then
								set include to true
							end if
						end repeat
					else
						if (_typeToString(argTypeOption) as text is _typeToString(theType) as text) or (_typeList(argTypeOption) and _typeList(theType)) then
							set include to true
						end if
					end if
				end repeat
			else
				if class of theType is list then
					set include to false
					repeat with filterTypeOption in theType
						if (filterTypeOption is not in anyListType and _typeToString(theArg's type class) as text is _typeToString(filterTypeOption) as text) or (filterTypeOption is in anyListType and _typeList(theArg's type class)) then
							set include to true
						end if
					end repeat
				else
					if (theType is in anyListType or _typeToString(theArg's type class) as text is not _typeToString(theType) as text) and not (theType is in anyListType and _typeList(theArg's type class)) then
						set include to false
					end if
				end if
			end if
		end if

		if isRequired is not missing value then
			if theArg's «class Agru» is not isRequired then set include to false
		end if

		if hasValue is not missing value then
			if theArg's «class Agst» is missing value then
				set include to false
			else
				if (theArg's «class Agst»'s «class Agsv» is "" and hasValue is true) or (theArg's «class Agst»'s «class Agsv» is not "" and hasValue is false) then set include to false
			end if
		end if

		if customFilter is not missing value then
			if not customFilter's execute(theArg) then set include to false
		end if

		if include then
			set end of filteredArgs to theArg
		end if
	end repeat
	return get filteredArgs
end «event ©!Ag©!Fi»

on «event ©!Ag©!in» given «class !ipc»:theConfig : missing value
	set my globalHelpText to "
"

	set requiredHelpText to " Required Arguments:

"
	set optionalHelpText to " Optional Arguments:

"
	set numRequired to 0
	set numOptional to 0
	repeat with theArg in my args
		set flagText to ""
		if theArg's «class Agfl» is not missing value then
			set flagText to ", " & theArg's «class Agfl»
		end if
		if «class Agru» of theArg is true then
			if «class Aght» of theArg is not "" then
				set requiredHelpText to requiredHelpText & "	" & name of theArg & flagText & " - " & «class Aght» of theArg & "
"
			else
				set requiredHelpText to requiredHelpText & "	" & name of theArg & flagText & "
"
			end if
			set numRequired to numRequired + 1
		else
			if «class Aght» of theArg is not "" then
				set optionalHelpText to optionalHelpText & "	" & name of theArg & flagText & " - " & «class Aght» of theArg & "
"
			else
				set optionalHelpText to optionalHelpText & "	" & name of theArg & flagText & "
"
			end if
			set numOptional to numOptional + 1
		end if
	end repeat

	if numRequired > 0 then
		set my globalHelpText to my globalHelpText & requiredHelpText
		if numOptional > 0 then
			set my globalHelpText to my globalHelpText & ""
		end if
	end if

	try
		if theConfig's «class Agem» is «constant !Aem*AeC» then
			set optionalHelpText to optionalHelpText & "	errorMode - values: raise, log (default), optional. Controls how errors are handled by the script.
"
		end if
	end try
	set optionalHelpText to optionalHelpText & "	help, -h - Optional. Displays this help text.
"

	if numRequired > 0 then
		set my globalHelpText to my globalHelpText & "
"
	end if
	set my globalHelpText to my globalHelpText & optionalHelpText

	set helpTextHeader to "
 " & name of me
	set commandName to name of me
	set commandAuthor to ""
	set shortDescription to ""
	set longDescription to ""
	set footer to ""

	if theConfig is not missing value then
		try
			set commandName to theConfig's «class Agpn»
		end try

		try
			set commandAuthor to theConfig's «class Agat»
		end try

		try
			set shortDescription to theConfig's «class Apsd»
		end try

		try
			set longDescription to theConfig's «class Apld»
		end try

		if longDescription is not "" then
			set longDescription to longDescription & "

"
		end if

		try
			set my allowPositionalArguments to theConfig's «class Agpp»
		end try

		try
			set my errorMode to theConfig's «class Agem»
		end try

		if commandName is not "" then
			set helpTextHeader to "
 " & commandName
		end if

		if shortDescription is not "" then
			set helpTextHeader to helpTextHeader & " - " & shortDescription
		end if

		if commandAuthor is not "" then
			set helpTextHeader to helpTextHeader & "
Author: " & commandAuthor
		end if

		set helpTextHeader to helpTextHeader & "

"

		if longDescription is not "" then
			set helpTextHeader to helpTextHeader & "Description:
	" & longDescription
		end if

		set my globalHelpText to helpTextHeader & my globalHelpText

		try
			set my globalHelpText to my globalHelpText & theConfig's «class Agph»
		end try

		try
			set footer to theConfig's «class Agft»
		end try
		if footer is not "" then
			set my globalHelpText to my globalHelpText & "
" & footer
		end if

		try
			if theConfig's «class Agem» is «constant !Aem*AeC» then
				«event ©!Ag©!ca» "errorMode" without «class !car» given «class !cva»:{"raise", "log"}, «class !cdv»:"log", «class !cah»:"Controls how errors are handled. A value of 'raise' will raise standard AppleScript errors when arguments are missing or invalid, while a valid of 'log' will log formatted help text."
			end if
		end try
	else
		set helpTextHeader to "Script '" & commandName & "'

"
		set my globalHelpText to helpTextHeader & globalHelpText
	end if
	«event ©!Ag©!ca» "help" without «class !car» given «class !caf»:"h", «class !cat»:«constant !Aat*AtF», «class !caa»:_showGlobalHelpText
	set my shouldClearData to true
end «event ©!Ag©!in»

on «event ©!Ag©!cm» argv
	set showingGlobalHelp to false
	set showingSpecificHelp to false

	set flagLookahead to missing value
	set nextIndex to 1
	repeat with i from 1 to length of my args
		set theArg to item i of my args

		set previousArg to missing value
		if i > 1 then
			set previousArg to item (i - 1) of my args
		end if

		if my allowPositionalArguments is true then
			set argStatus to «event ©!Ag©!c1» theArg given «class !cav»:argv, «class !cai»:nextIndex
		else
			set argStatus to «event ©!Ag©!c1» theArg given «class !cav»:argv
		end if

		if argStatus's «class Agsp»'s endIndex > 0 then
			set nextIndex to (argStatus's «class Agsp»'s endIndex) + 1
		end if

		set theArg's «class Agst» to argStatus
		if argStatus's «class Agss» is not «constant !Aas*AsM» and argStatus's «class Agss» is not «constant !Aas*AsE» then
			if theArg's name is "help" then
				set showingGlobalHelp to true
			end if

			if (argStatus's «class Agsv») as text is "help" then
				set showingSpecificHelp to true
			end if

			if theArg's type class is «constant !Aat*AtF» then
				set nextIndex to (theArg's «class Agst»'s «class Agsp»'s endIndex) + 1
				if nextIndex ≤ length of argv then
					set nextValue to item nextIndex of argv
					if nextValue is "help" then
						set showingSpecificHelp to true
						set theArg's «class Agst»'s «class Agsv» to "help"
					end if
				end if
			end if
		end if
	end repeat

	set validArgs to {}
	set validArgNames to {}
	repeat with theArg in my args
		if theArg's «class Agst»'s «class Agss» is «constant !Aas*AsV» then
			copy theArg to end of validArgs
			copy name of theArg to end of validArgNames
		end if
	end repeat

	repeat with validArg in validArgs
		set theArg to _nameToArg(name of validArg, my args)
		if length of theArg's «class Agfd» > 0 then
			set argsNeeded to {}
			repeat with dependencyName in theArg's «class Agfd»
				if dependencyName is in («event ©!Ag©!an») then
					if dependencyName is not in validArgNames then
						set validArg's «class Agst»'s «class Agss» to «constant !Aas*AsI»
						copy dependencyName to end of argsNeeded
					end if
				end if
			end repeat
			if validArg's «class Agst»'s «class Agss» is «constant !Aas*AsI» then
				if length of argsNeeded is 1 then
					set validArg's «class Agst»'s «class Ager» to "The '" & item 1 of argsNeeded & "' argument must co-occur with the '" & name of validArg & "' argument. Both arguments must have valid values."
				else if length of argsNeeded > 1 then
					set dependencyListText to ""
					repeat with dependencyName in argsNeeded
						set dependencyListText to dependencyListText & dependencyName & ", "
					end repeat
					set endIdx to (length of dependencyListText) - 2
					set dependencyListText to (text 1 thru endIdx of dependencyListText)
					set validArg's «class Agst»'s «class Ager» to "The '" & validArg's name & "' argument must co-occur with all of the following arguments: " & dependencyListText & "."
				end if
			end if
		end if
	end repeat

	if not showingGlobalHelp then
		repeat with i from 1 to length of my args
			set theArg to item i of my args
			if (not showingSpecificHelp and theArg's «class Agst»'s «class Agss» is «constant !Aas*AsI») or theArg's «class Agst»'s «class Agsv» as text is "help" then
				_showHelpText(theArg, theArg's «class Agst»'s «class Agss», theArg's «class Agst»'s «class Agsv», theArg's «class Agst»'s «class Ager»)
			else if not showingSpecificHelp and theArg's «class Agst»'s «class Agss» is «constant !Aas*AsM» then
				_showMissingText(theArg, theArg's «class Agst»'s «class Agss», theArg's «class Agst»'s «class Agsv»)
			end if
		end repeat
	end if

	return my args
end «event ©!Ag©!cm»

on «event ©!Ag©!c1» theArg given «class !cav»:argv, «class !cai»:targetIndex : -1
	set theState to «constant !Aas*AsM»
	set argSpan to {startIndex:-1, endIndex:-1}
	set errorReason to ""

	if «class Agru» of theArg is false then
		set theState to «constant !Aas*AsE»
	end if

	if class of argv is script or length of argv < 1 then
		return {name:name of theArg, «class Agss»:theState, «class Agsv»:"", «class Agsp»:argSpan, «class Ager»:errorReason}
	end if

	set targets to {"--" & name of theArg}
	if «class Agfl» of theArg is not "" then
		copy ("-" & «class Agfl» of theArg) to end of targets
	end if

	set idx to 1
	if targetIndex > 0 then
		set idx to targetIndex
	end if

	set dataIdx to 1

	set argListTypes to [«constant !AatAtAl», «constant !AatAtIl», «constant !AatAtDl», «constant !AatAtBl», «constant !AatAtPl», «constant !AatAtUl», «constant !AatAtJl»]
	set typeIsListOfTypes to (class of theArg's type class is list)

	repeat while idx ≤ length of argv
		try
			set currentArg to item idx of argv
			if currentArg starts with "-" and currentArg is not "-" then
				set my allowPositionalArguments to false
				repeat with target in targets
					if (target as text) is (currentArg as text) then
						if type class of theArg is «constant !Aat*AtF» then
							set dataIdx to idx + 1
							set theState to «constant !Aas*AsV»
						else if theArg's type class is in argListTypes or typeIsListOfTypes and _anyInList(theArg's type class, argListTypes) then
							set argSpan to _getArgListSpan(idx + 1, argv)
							set theState to «constant !Aas*AsI»
							exit repeat
						end if

						if theState is not «constant !Aas*AsI» and theState is not «constant !Aas*AsV» then
							set dataIdx to idx + 1
							set theState to «constant !Aas*AsI»
						end if
						set argSpan to {startIndex:idx, endIndex:dataIdx - 1}
						exit repeat
					end if
				end repeat
			else if my allowPositionalArguments is true and idx is «class Agps» of theArg and type class of theArg is not «constant !Aat*AtF» then
				if theArg's type class is in argListTypes or typeIsListOfTypes and _anyInList(theArg's type class, argListTypes) then
					set argSpan to _getArgListSpan(idx, argv)
					set theState to «constant !Aas*AsI»
					exit repeat
				end if

				if theState is not «constant !Aas*AsI» then
					set dataIdx to idx
					set argSpan to {startIndex:idx, endIndex:dataIdx}
					set theState to «constant !Aas*AsI»
					exit repeat
				end if
			end if

			if theState is not «constant !Aas*AsM» and theState is not «constant !Aas*AsE» then
				exit repeat
			end if
		on error err
			_displayError(err)
		end try
		set idx to idx + 1
	end repeat

	set theValue to ""

	if (theState is «constant !Aas*AsM» or theState is «constant !Aas*AsE») and (theArg's «class Agdv» is not missing value) then
		set theValue to theArg's «class Agdv»
		set theState to «constant !Aas*AsI»
	end if

	if theState is «constant !Aas*AsI» then
		if dataIdx ≤ length of argv then
			if theValue is "" then
				set theValue to item dataIdx of argv
			end if

			if theArg's «class Aacv» is not missing value then
				if theValue is in theArg's «class Aacv» then
					-- String value is in accepted values
					set theState to «constant !Aas*AsV»
				else
					-- Perform automatic conversions, then check against accepted values
					if _isInteger(theValue) and (theValue as integer) is in theArg's «class Aacv» then
						set theValue to theValue as integer
						set theState to «constant !Aas*AsV»
					else if _isDecimal(theValue) and (theValue as real) is in theArg's «class Aacv» then
						set theValue to theValue as real
						set theState to «constant !Aas*AsV»
					else if _isBoolean(theValue) and (theValue as boolean) is in theArg's «class Aacv» then
						set theValue to theValue as boolean
						set theState to «constant !Aas*AsV»
					end if
				end if

				if theState is not «constant !Aas*AsV» then
					if length of theArg's «class Aacv» is 1 then
						set errorReason to "The value you provided (" & theValue & ") is not an accepted value for this argument. The value must be " & item 1 of theArg's «class Aacv» & "."
					else if length of theArg's «class Aacv» > 1 then
						set acceptedValueText to ""
						repeat with i from 1 to length of theArg's «class Aacv»
							set acceptedValue to item i of theArg's «class Aacv»

							if not _isInteger(acceptedValue) and not _isDecimal(acceptedValue) and not _isBoolean(acceptedValue) then
								set acceptedValue to quoted form of acceptedValue
							end if

							if i < (length of theArg's «class Aacv») - 1 then
								set acceptedValueText to acceptedValueText & acceptedValue & ", "
							else if i is (length of theArg's «class Aacv») - 1 then
								if length of theArg's «class Aacv» is 2 then
									set acceptedValueText to acceptedValueText & acceptedValue & " or "
								else
									set acceptedValueText to acceptedValueText & acceptedValue & ", or "
								end if
							else if i is length of theArg's «class Aacv» then
								set acceptedValueText to acceptedValueText & acceptedValue
							end if
						end repeat
						set errorReason to "The value you provided (" & theValue & ") is not an accepted value for this argument. The value must be " & acceptedValueText & "."
					end if
				end if
			else
				if theArg's type class is «constant !Aat*AtA» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtA» is in theArg's type class) then
					set theState to «constant !Aas*AsV»
				end if

				if theArg's type class is «constant !Aat*AtI» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtI» is in theArg's type class) then
					try
						set x to theValue as number
						if class of x is integer then
							set theValue to x
							set theState to «constant !Aas*AsV»
						else
							set errorReason to "The value you provided (" & theValue & ") is not an integer value."
						end if
					on error
						set errorReason to "The value you provided (" & theValue & ") is not an integer value."
					end try
				end if

				if theArg's type class is «constant !Aat*AtD» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtD» is in theArg's type class) then
					try
						set theValue to theValue as real
						set theState to «constant !Aas*AsV»
					on error
						set errorReason to "The value you provided (" & theValue & ") is not a decimal value."
					end try
				end if

				if theArg's type class is «constant !Aat*AtB» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtB» is in theArg's type class) then
					try
						set theValue to theValue as boolean
						set theState to «constant !Aas*AsV»
					on error
						set errorReason to "The value you provided (" & theValue & ") is not a boolean value."
					end try
				end if

				if theArg's type class is «constant !Aat*AtP» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtP» is in theArg's type class) then
					try
						-- Attempt to convert value to POSIX file object
						set theValue to my POSIX file theValue
						set theState to «constant !Aas*AsV»
					on error
						set errorReason to "The value you provided (" & theValue & ") is not a valid path on the disk."
					end try
				end if

				if theArg's type class is «constant !Aat*AtU» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtU» is in theArg's type class) then
					try
						-- Attempt to convert value to URL object
						set theValue to theValue as URL
						set theState to «constant !Aas*AsV»
					on error
						set errorReason to "The value you provided (" & theValue & ") is not a valid URL."
					end try

					if theState is not «constant !Aas*AsV» then
						-- Catch-all for URL-like strings that cannot be made into URL objects (e.g. ones that use an unknown scheme)
						try
							set theURL to current application's NSURL's URLWithString:theValue
							set theScheme to theURL's |scheme|()
							if theScheme is not missing value then
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "The value you provided (" & theValue & ") is not a valid URL."
							end if
						end try
					end if
				end if

				if theArg's type class is «constant !Aat*AtJ» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !Aat*AtJ» is in theArg's type class) then
					if _isJSON(theValue) then
						set theState to «constant !Aas*AsV»
					else
						set errorReason to "The value you provided ('" & theValue & "') is not a valid JSON string."
					end if
				end if

				if theArg's type class is in argListTypes or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and _anyInList(theArg's type class, argListTypes)) then
					set startIdx to startIndex of argSpan
					set endIdx to endIndex of argSpan
					try
						set theValue to items startIdx thru endIdx of argv
						if theArg's type class is «constant !AatAtIl» or (typeIsListOfTypes and «constant !AatAtIl» is in theArg's type class) then
							if _allIntegers(theValue) then
								set newValue to {}
								repeat with theItem in theValue
									set x to theItem as integer
									copy x to end of newValue
								end repeat
								set theValue to newValue
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "Each item in the list must be an integer or a string that parses into an integer (e.g. '3')."
							end if
						end if

						if theArg's type class is «constant !AatAtDl» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !AatAtDl» is in theArg's type class) then
							if _allDecimals(theValue) then
								set newValue to {}
								repeat with theItem in theValue
									set x to theItem as real
									copy x to end of newValue
								end repeat
								set theValue to newValue
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "Each item in the list must be a real number or a string that parses into a number (e.g. '3.14')."
							end if
						end if

						if theArg's type class is «constant !AatAtBl» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !AatAtBl» is in theArg's type class) then
							if _allBooleans(theValue) then
								set newValue to {}
								repeat with theItem in theValue
									set x to theItem as boolean
									copy x to end of newValue
								end repeat
								set theValue to newValue
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "Each item in the list must be true or false."
							end if
						end if

						if theArg's type class is «constant !AatAtPl» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !AatAtPl» is in theArg's type class) then
							if _allPaths(theValue) then
								set newValue to {}
								repeat with theItem in theValue
									set x to POSIX path of theItem
									copy x to end of newValue
								end repeat
								set theValue to newValue
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "Each item in the list must be a valid path that exists on the disk."
							end if
						end if

						if theArg's type class is «constant !AatAtUl» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !AatAtUl» is in theArg's type class) then
							if _allURLs(theValue) then
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "Each item in the list must be a valid URL in the form scheme://host."
							end if
						end if

						if theArg's type class is «constant !AatAtJl» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !AatAtJl» is in theArg's type class) then
							if _allJSON(theValue) then
								set theState to «constant !Aas*AsV»
							else
								set errorReason to "Each item in the list must be a valid JSON string representing a top-level object."
							end if
						end if

						if theArg's type class is «constant !AatAtAl» or (theState is not «constant !Aas*AsV» and typeIsListOfTypes and «constant !AatAtAl» is in theArg's type class) then
							set theState to «constant !Aas*AsV»
						end if
					on error err
						_displayError(err)
					end try
				end if
			end if

			-- Apply custom validator after appropriate conversions applied based on arg type
			if «class Agav» of theArg is not missing value then
				set validityResult to theArg's «class Agav»'s execute(theArg's name, theValue)
				try
					set theState to validityResult's «class Agvv»
					set theValue to validityResult's «class Agsv»
				end try
			end if
		else
			set errorReason to "You must provide a value for this argument."
		end if
	end if

	if theArg's «class Agac» is not missing value then
		theArg's «class Agac»'s execute(theArg, theState, theValue)
	end if

	return {name:name of theArg, «class Agss»:theState, «class Ager»:errorReason, «class Agsv»:theValue, «class Agsp»:argSpan}
end «event ©!Ag©!c1»

on «event ©!Ag©!ha» argv given «class !hne»:onNoErrors : missing value, «class !hav»:onAllValid : missing value, «class !hai»:onAllInvalid : missing value, «class !hae»:onAllExcluded : missing value, «class !ham»:onAllMissing : missing value, «class !hva»:onAnyValid : missing value, «class !hia»:onAnyInvalid : missing value, «class !hea»:onAnyExcluded : missing value, «class !hma»:onAnyMissing : missing value

	set noErrorsHandler to missing value
	set allValidHandler to missing value
	set allInvalidHandler to missing value
	set allExcludedHandler to missing value
	set allMissingHandler to missing value
	set anyValidHandler to missing value
	set anyInvalidHandler to missing value
	set anyExcludedHandler to missing value
	set anyMissingHandler to missing value

	if onNoErrors is not missing value then set noErrorsHandler to _wrapHandler(onNoErrors, «class !AHa»)
	if onAllValid is not missing value then set allValidHandler to _wrapHandler(onAllValid, «class !AHa»)
	if onAllInvalid is not missing value then set allInvalidHandler to _wrapHandler(onAllInvalid, «class !AHa»)
	if onAllExcluded is not missing value then set allExcludedHandler to _wrapHandler(onAllExcluded, «class !AHa»)
	if onAllMissing is not missing value then set allMissingHandler to _wrapHandler(onAllMissing, «class !AHa»)
	if onAnyValid is not missing value then set anyValidHandler to _wrapHandler(onAnyValid, «class !AHa»)
	if onAnyInvalid is not missing value then set anyInvalidHandler to _wrapHandler(onAnyInvalid, «class !AHa»)
	if onAnyExcluded is not missing value then set anyExcludedHandler to _wrapHandler(onAnyExcluded, «class !AHa»)
	if onAnyMissing is not missing value then set anyMissingHandler to _wrapHandler(onAnyMissing, «class !AHa»)

	«event ©!Ag©!cm» argv
	set validArgs to {}
	set invalidArgs to {}
	set excludedArgs to {}
	set missingArgs to {}
	set helpArgModifier to 0

	set argSummary to current application's NSMutableDictionary's alloc()'s init()
	repeat with theArg in my args
		set argState to theArg's «class Agst»'s «class Agss»
		if argState is «constant !Aas*AsV» then
			set end of validArgs to theArg
		else if argState is «constant !Aas*AsI» then
			set end of invalidArgs to theArg
		else if argState is «constant !Aas*AsE» then
			set end of excludedArgs to theArg
			if name of theArg is "help" then
				set helpArgModifier to 1
			end if
		else if argState is «constant !Aas*AsM» then
			set end of missingArgs to theArg
		end if

		if (name of theArg) as text is not "help" then
			(argSummary's setValue:(theArg's «class Agst»'s «class Agsv») forKey:(name of theArg))
		else if argState is «constant !Aas*AsV» then
			return
		end if
	end repeat

	set theResult to ""
	if length of missingArgs is 0 and length of invalidArgs is 0 then
		if noErrorsHandler is not missing value then set theResult to noErrorsHandler's execute(validArgs & excludedArgs, argSummary as record)
	end if

	if (length of validArgs) + helpArgModifier is (length of my args) then
		if allValidHandler is not missing value then set theResult to allValidHandler's execute(validArgs, argSummary as record)
	else if length of validArgs > 0 then
		if anyValidHandler is not missing value then set theResult to anyValidHandler's execute(validArgs, argSummary as record)
	end if

	if (length of invalidArgs) + helpArgModifier is (length of my args) then
		if allInvalidHandler is not missing value then set theResult to allInvalidHandler's execute(invalidArgs, argSummary as record)
	else if length of invalidArgs > 0 then
		if anyInvalidHandler is not missing value then set theResult to anyInvalidHandler's execute(invalidArgs, argSummary as record)
	end if

	if length of excludedArgs is (length of my args) then
		if allExcludedHandler is not missing value then set theResult to allExcludedHandler's execute(excludedArgs, argSummary as record)
	else if length of excludedArgs > helpArgModifier then
		if anyExcludedHandler is not missing value then set theResult to anyExcludedHandler's execute(excludedArgs, argSummary as record)
	end if

	if (length of missingArgs) + helpArgModifier is (length of my args) then
		if allMissingHandler is not missing value then set theResult to allMissingHandler's execute(missingArgs, argSummary as record)
	else if length of missingArgs > 0 then
		if anyMissingHandler is not missing value then set theResult to anyMissingHandler's execute(missingArgs, argSummary as record)
	end if

	set my shouldClearData to true
	try
		if theResult is not missing value then
			return theResult
		end if
	on error
		-- User-provided handler did not return any result
	end try
end «event ©!Ag©!ha»



(*
 * Utility Methods
 ***************)

(*
 * Gets a full argument record given its name.
 *)
on _nameToArg(theName as text, args)
	repeat with theArg in args
		if (name of theArg) as text is theName then
			return theArg
		end if
	end repeat
end _nameToArg

(*
 * Checks if any item in valuesToCheck exists in theList.
 *)
on _anyInList(theList, valuesToCheck)
	repeat with theValue in valuesToCheck
		if theValue is in theList then return true
	end repeat
	return false
end _anyInList

(*
 * Gets the start and end index of an argument's value(s) within the argv list.
 *)
on _getArgListSpan(startIndex, argv)
	set innerIdx to startIndex
	repeat while innerIdx ≤ length of argv
		set innerArg to item innerIdx of argv
		if innerArg starts with "-" and innerArg is not "-" then
			exit repeat
		end if
		set innerIdx to innerIdx + 1
	end repeat
	if (innerIdx is startIndex) then
		set innerIdx to startIndex + 1
	end if
	return {startIndex:startIndex, endIndex:innerIdx - 1}
end _getArgListSpan

-- Type Handling --

(*
 * Maps any accepted argument type specifier to its corresponding argument type constant.
 *)
on _standardizeType(theType)
	if class of theType is list then
		if length of theType is 0 then
			return «constant !Aat*AtA»
		else if length of theType is 1 then
			return _standardizeType(item 1 of theType)
		end if

		set standardizedTypes to {}
		repeat with aType in theType
			set end of standardizedTypes to _standardizeType(aType)
		end repeat
		return standardizedTypes
	end if

	if _typeFlag(theType) then return «constant !Aat*AtF»
	if _typeAny(theType) then return «constant !Aat*AtA»
	if _typeInteger(theType) then return «constant !Aat*AtI»
	if _typeDecimal(theType) then return «constant !Aat*AtD»
	if _typeBoolean(theType) then return «constant !Aat*AtB»
	if _typeURL(theType) then return «constant !Aat*AtU»
	if _typePath(theType) then return «constant !Aat*AtP»
	if _typeJSON(theType) then return «constant !Aat*AtJ»

	if _typeAnyList(theType) or theType is in {«constant !Aat*AtL»} then return «constant !AatAtAl»
	if _typeIntegerList(theType) then return «constant !AatAtIl»
	if _typeDecimalList(theType) then return «constant !AatAtDl»
	if _typeBooleanList(theType) then return «constant !AatAtBl»
	if _typeURLList(theType) then return «constant !AatAtUl»
	if _typePathList(theType) then return «constant !AatAtPl»
	if _typeJSONList(theType) then return «constant !AatAtJl»
end _standardizeType

(*
 * Maps Argonaut argument type constants to descriptive string names.
 *)
on _typeToString(theType)
	set argType to "any"
	if _typeInteger(theType) then
		set argType to "integer"
	else if _typeAnyList(theType) then
		set argType to "list of any type"
	else if _typeIntegerList(theType) then
		set argType to "list of integers"
	else if _typeDecimal(theType) then
		set argType to "decimal"
	else if _typeDecimalList(theType) then
		set argType to "list of decimal numbers"
	else if _typeBoolean(theType) then
		set argType to "boolean"
	else if _typeBooleanList(theType) then
		set argType to "list of true/false"
	else if _typePath(theType) then
		set argType to "file path"
	else if _typePathList(theType) then
		set argType to "list of paths"
	else if _typeURL(theType) then
		set argType to "URL"
	else if _typeURLList(theType) then
		set argType to "list of URLs"
	else if _typeFlag(theType) then
		set argType to "flag (either present or not))"
	else if _typeJSON(theType) then
		set argType to "top-level JSON object"
	else if _typeJSONList(theType) then
		set argType to "JSON object list"
	end if
	return argType
end _typeToString

on _typeFlag(theType)
	return theType is in {«constant !Aat*AtF», "flag"}
end _typeFlag

(*
 * Returns true if theType is any valid representation of the "any" type.
 *)
on _typeAny(theType)
	return theType is in {anything, «constant !Aat*AtA», "any", "anything"}
end _typeAny

(*
 * Returns true if theType is any valid representation of the integer type.
 *)
on _typeInteger(theType)
	return theType is in {integer, «constant !Aat*AtI», "integer", "int"}
end _typeInteger

(*
 * Returns true if theType is any valid representation of the decimal type.
 *)
on _typeDecimal(theType)
	return theType is in {number, real, «constant !Aat*AtD», "number", "real", "decimal"}
end _typeDecimal

(*
 * Returns true if theType is any valid representation of the boolean type.
 *)
on _typeBoolean(theType)
	return theType is in {boolean, «constant !Aat*AtB», "bool", "boolean"}
end _typeBoolean

(*
 * Returns true if theType is any valid representation of the URL type.
 *)
on _typeURL(theType)
	return theType is in {URL, «constant !Aat*AtU», "url", "link"}
end _typeURL

(*
 * Returns true if theType is any valid representation of the path type.
 *)
on _typePath(theType)
	return theType is in {«constant !Aat*AtP», "path"}
end _typePath

(*
 * Returns true if theType is any valid representation of the JSON type.
 *)
on _typeJSON(theType)
	return theType is in {«constant !Aat*AtJ», "json"}
end _typeJSON

(*
 * Returns if the theType is a valid representation of *any* list type.
 *)
on _typeList(theType)
	return _typeAnyList(theType) or _typeIntegerList(theType) or _typeDecimalList(theType) or _typeBooleanList(theType) or _typeURLList(theType) or _typePathList(theType) or _typeJSONList(theType) or theType is in {«constant !Aat*AtL»}
end _typeList


(*
 * Returns true if theType is any valid representation of the "list of any" type.
 *)
on _typeAnyList(theType)
	return theType is in {«constant !AatAtAl», "list", "list of any"}
end _typeAnyList

(*
 * Returns true if theType is any valid representation of the "list of integer" type.
 *)
on _typeIntegerList(theType)
	return theType is in {«constant !AatAtIl», "list of int", "list of integer"}
end _typeIntegerList

(*
 * Returns true if theType is any valid representation of the "list of decimal" type.
 *)
on _typeDecimalList(theType)
	return theType is in {«constant !AatAtDl», "list of decimal", "list of number", "list of real", "list of float", "list of double"}
end _typeDecimalList

(*
 * Returns true if theType is any valid representation of the "list of boolean" type.
 *)
on _typeBooleanList(theType)
	return theType is in {«constant !AatAtBl», "list of bool", "list of boolean"}
end _typeBooleanList

(*
 * Returns true if theType is any valid representation of the "list of URL" type.
 *)
on _typeURLList(theType)
	return theType is in {«constant !AatAtUl», "list of URL", "list of link"}
end _typeURLList

(*
 * Returns true if theType is any valid representation of the "list of path" type.
 *)
on _typePathList(theType)
	return theType is in {«constant !AatAtPl», "list of path", "list of alias", "list of POSIX path"}
end _typePathList

(*
 * Returns true if theType is any valid representation of the JSON object list type.
 *)
on _typeJSONList(theType)
	return theType is in {«constant !AatAtJl», "list of JSON objects", "list of JSON"}
end _typeJSONList

(*
 * Returns true if x is an integer or can be directly parsed into an integer (e.g. the string '3').
 *)
on _isInteger(x)
	try
		set num to x as number
		if class of num is integer then
			return true
		end if
	end try
	return false
end _isInteger

(*
 * Returns true if every item in the given list is an integer or can be directly parsed into an integer (e.g. the string '3').
 *)
on _allIntegers(ls)
	repeat with x in ls
		if not _isInteger(x) then
			return false
		end if
	end repeat
	return true
end _allIntegers

(*
 * Returns true if x is a real number or can be directly parsed into a real number (e.g. the string '3.14').
 *)
on _isDecimal(x)
	try
		set num to x as number
		return true
	end try
	return false
end _isDecimal

(*
 * Returns true if every item in the given list is a real number or can be directly parsed into a real number (e.g. the string '3.14').
 *)
on _allDecimals(ls)
	repeat with x in ls
		if not _isDecimal(x) then
			return false
		end if
	end repeat
	return true
end _allDecimals

(*
 * Returns true if x is true, false, 'true', or 'false'.
 *)
on _isBoolean(x)
	try
		set num to x as boolean
		if class of num is boolean then
			return true
		end if
	end try
	return false
end _isBoolean

(*
 * Returns true if every item in the given list is true, false, 'true', or 'false'.
 *)
on _allBooleans(ls)
	repeat with x in ls
		if not _isBoolean(x) then
			return false
		end if
	end repeat
	return true
end _allBooleans

(*
 * Returns true if x is a path that exists on the local disk.
 *)
on _isPath(x)
	set thePath to POSIX path of x
	set pathExists to (do shell script "if [ -e " & quoted form of thePath & " ]; then echo true; else echo false; fi")
	return pathExists is "true"
end _isPath

(*
 * Returns true if every item in the given list is a path that exists on the local disk.
 *)
on _allPaths(ls)
	repeat with x in ls
		if not _isPath(x) then
			return false
		end if
	end repeat
	return true
end _allPaths

(*
 * Returns true if x is a URL with a defined scheme.
 *)
on _isURL(x)
	set theURL to current application's NSURL's URLWithString:x
	set theScheme to theURL's |scheme|()
	if theScheme is not missing value then
		return true
	end if
	return false
end _isURL

(*
 * Returns true if every item in the given list is a URL with a defined scheme.
 *)
on _allURLs(ls)
	repeat with x in ls
		if not _isURL(x) then
			return false
		end if
	end repeat
	return true
end _allURLs

(*
 * Returns true if x is a valid top-level JSON string.
 *)
on _isJSON(x)
	try
		set theData to (current application's NSString's stringWithString:x)'s dataUsingEncoding:(current application's NSUTF8StringEncoding)
		set jsonObj to current application's NSJSONSerialization's JSONObjectWithData:theData options:(0) |error|:(missing value)
		if jsonObj is not missing value then return true
	end try
	return false
end _isJSON

(*
 * Returns true if every item in the given list is a valid top-level JSON string.
 *)
on _allJSON(ls)
	repeat with x in ls
		if not _isJSON(x) then
			return false
		end if
	end repeat
	return true
end _allJSON
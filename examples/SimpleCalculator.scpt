#@osa-lang:AppleScript
(*
 * Example script utilizing the Argonaut library.
 *
 * Applies a mathematical operation sequentially on a list of operands.
 *
 * To invoke:
 * osascript SimpleCalculator.scpt "*" 5 10 2 2.5					# 250.0
 * osascript SimpleCalculator.scpt --operands 4 8 2 16 --operation + 	# 30.0
 * osascript SimpleCalculator.scpt -h								# Displays help text
 *)

use script "Argonaut" version "1.0"

-- Math operation utility handlers
on add(ls)
	set sum to 0
	repeat with num in ls
		set sum to sum + num
	end repeat
	return sum
end add

on subtract(ls)
	set diff to item 1 of ls
	repeat with num in (items 2 thru end of ls)
		set diff to diff - num
	end repeat
	return diff
end subtract

on multipy(ls)
	set product to item 1 of ls
	repeat with num in (items 2 thru end of ls)
		set product to product * num
	end repeat
	return product
end multipy

on divide(ls)
	set quotient to item 1 of ls
	repeat with num in (items 2 thru end of ls)
		set quotient to quotient / num
	end repeat
	return quotient
end divide

(*
 * Ensures the
 *)
on isValidOperation(theArg, theValue)
	set isValid to invalid
	if theValue is in ["+", "-", "*", "/"] then
		set isValid to valid
	end if
	return {validity:isValid, value:theValue}
end isValidOperation

script ResultHandler
	on handle(args, theSummary)
		set op to operation of theSummary
		if op is "+" then
			return add(operands of theSummary)
		else if op is "-" then
			return subtract(operands of theSummary)
		else if op is "*" then
			return multipy(operands of theSummary)
		else if op is "/" then
			return divide(operands of theSummary)
		end if
	end handle
end script

on run argv
	add argument "operation" help text "The mathematical operation (+, -, *, /)" validator isValidOperation
	add argument "operands" type ArgDecimalList help text "A list of numeric operands to apply the operation to sequentially."

	set config to {command name:"Simple Calculator", short description:"A very basic calculator for performing sequential operations on lists of numbers."}
	initialize argument parser configuration config

	if class of argv is not list then
		error "This script must be run from the commandline"
	end if
	handle arguments argv when no errors ResultHandler
end run
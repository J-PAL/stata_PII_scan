/*********************************************************************************************************************************************
Description: This file will scan all .dta files within a directory and all of its subdirectories for potential PII. Potential PII includes 
variables with names or labels containing any of the strings in global search_string. The program decodes all encoded numeric variables (i.e. 
those with value labels or those created using the command "encode") to create string variables, which are searched along with all original 
string variables for variables with string lengths greater than 3 (or user-defined length). Flagged variables are saved to pii_stata_output.xlsx. 

Inputs: Path to top directory.
Outputs: pii_stata_output.xlsx (saved to current working directory)
Date Last Modified: March 21, 2018
Last Modified By: Marisa Carlos (mcarlos@povertyactionlab.org)
**********************************************************************************************************************************************/

version 15.1
clear all
set more off 
set maxvar 120000


*sysdir set PLUS "" 
*sysdir set PERSONAL ""

cd "" // CHANGE PATH TO WHERE YOU WANT TO SAVE pii_stata_output.xlsx
global directory_to_scan "" // SET THIS DIRECTORY TO THE ONE YOU WANT TO SCAN (change options at botton of do-file)


***Command "filelist" required:
capture ssc install filelist


****************************** ADD OR REMOVE SEARCH STRINGS AS NEEDED: ******************************
#delimit ;
global search_strings
	address
	bday
	beneficiary
	birth 
	block
	census
	child
	city
	community
	compound
	coord
	country
	degree
	district
	dob
	daughter
	email
	father
	fax
	gender
	gps
	house
	husband
	lat
	loc 
	location
	lon
	minute
	mother
	municipality
	name
	network
	panchayat
	parish
	phone 
	precinct
	school
	second
	sex
	social
	son
	spouse 
	street
	subcountry
	territory
	url
	village
	wife
	zip
;
#delimit cr;
*****************************************************************************************************

capture program drop pii_scan
program pii_scan
	syntax anything(name=search_directory id="path of directory to search")[, remove_search_list(string) add_search_list(string) ignore_varname(string) string_length(integer 3) samples(integer 5)]
	/*
	EXPLANATION OF INPUTS:
		search_directory = path of directory to search 
		remove_search_list = list of strings to remove from the search list (e.g. if you don't want to search for string with "zip" or "wife" in the name or label, use 
							 option remove_search_list(zip wife)
		add_search_list = list of strings to add to the search list (e.g. if you also want to search for "person" in name/label, use option add_search_list(person)
		ignore_varname = A list of strings such that if there are any variables flagged with any of these strings in the VARIABLE NAME, they will NOT be output to the excel file 
				(e.g. if you don't want any variables with the word "materials" to be output to pii_stata_output.xlsx, use option "ignore(materials)"). 
				NOTE: This does not ignore the word if it is only found in the variable label.
		string_length = the cutoff length for the strings you want to be flagged. The default is 3 (i.e. strings with lengths greater than 3 will be output to excel file)
		samples = number of samples to output to excel, default is 5
	*/
	
	*make list of user defined search strings to ignore lowercase:
	local ignore_strings
	foreach search_string of local remove_search_list {
		local string_lower = lower("`search_string'")
		local ignore_strings "`ignore_strings' `string_lower'"
	}
	*make list of user defined search strings to add lowercase:
	local add_strings
	foreach search_string of local add_search_list {
		local string_lower = lower("`search_string'")
		local add_strings "`add_strings' `string_lower'"
	}
	
	*Remove strings user defined from search list:
	global final_search_list : list global(search_strings) - ignore_strings
	
	*Add strings user defined to search list:
	global final_search_list : list global(final_search_list) | add_strings
	*Make sure list only contains unique values: 
	global final_search_list : list uniq global(final_search_list)
	
	tempfile file_list 
	filelist, directory(`search_directory') pattern("*.dta")
	gen temp="/"
	egen file_path = concat(dirname temp filename)
	keep file_path
	save `file_list'

	qui count
	forvalues i=1/`r(N)' {
		local file_`i' = file_path[`i']
	}

	qui putexcel set pii_stata_output.xlsx, replace
	local i=0
	foreach col in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE AF AG AH AI AJ AK AL AM AN AO AP AQ AR AS AT AU AV AW AX AY AZ {
		local col`++i' "`col'"
	}
	
	local i=0
	local row=1
	foreach header in "file" "var" "varlabel" "most freq value" "ratio of diff values/num obs" {
		qui putexcel `col`++i''`row' = `"`header'"'
	}
	forvalues j=1/`samples' {
		qui putexcel `col`++i''`row' = "samp`j'"
	}

	
	qui count
	forvalues i=1/`r(N)' {
		use "`file_`i''", clear
		qui count 
		local N = r(N) // USED WHEN OUTPUTING TO EXCEL
		***Initialize locals:
		local decoded_vars_original
		local decoded_vars_renamed
		local vars_output_csv
		local strings_to_output
		local string_vars
		local numeric_vars 
		local all_vars
		foreach var of varlist * {
			local all_vars "`all_vars' `var'"
		}

		*** Decode all of the string variables that are encoded (this creates a string variable that takes on the values of the value labels) 
		foreach var of varlist * {
			*** If the variable name is longer than 31 character, need to substring to get the first 31 letters so can add on DCD
			if length("`var'")>31 {
				local var_prefix = substr("`var'",1,31)
			}
			else {
				local var_prefix "`var'"
			}
			capture decode `var', gen(`var_prefix'DCD)
			if _rc==0 {
				local decoded_vars_original "`decoded_vars_original' `var'"
				local decoded_vars_renamed "`decoded_vars_renamed' `var_prefix'DCD"
			}
		}
		if "`decoded_vars_original'"!="" {
			local j=0
			foreach orig_var of local decoded_vars_original {
				local ++j
				local k=0
				foreach new_var of local decoded_vars_renamed {
					local ++k
					if `j'==`k' {
						drop `orig_var'
						rename `new_var' `orig_var'
					}
				}
			}
		}
		
		***Get list of all string variables (this will include original string variables and the decoded variables) 
		foreach var of varlist * {
			capture confirm string var `var'
			if _rc==0 {
				local string_vars "`string_vars' `var'"
			}
			else {
				local numeric_vars "`numeric_vars' `var'"
			}
		}

		***Save the list of string variables that have lengths greater than 3 (or user defined value):
		foreach var of local string_vars {
			tempvar temp1
			qui gen `temp1' = length(`var') // string length 
			qui sum `temp1'
			if `r(max)'>`string_length' {
				local var_name = lower("`var'")
				local lab: variable label `var'
				local add_to_flagged=1
				*Don't flag the variable if the variable name has any of the strings listed by the user in ignore_varname option:
				foreach ignore_string of local ignore_varname {
					local lower_ignore_string = lower("`ignore_string'")
					local ignore_name_pos = strpos("`var_name'","`lower_ignore_string'")
					if `ignore_name_pos'!=0 {
						local add_to_flagged=0
					}
				}
				if `add_to_flagged'==1 {
					display "`var' (label = `lab') has length > `string_length'"
					local strings_to_output "`strings_to_output' `var'"
				}
			}
			drop `temp1'
		}
		
		***Search through the rest of the variables and see if there are any of the PII search words in the variable names or labels:
		***Only look through variables that havent been assigned to be output to CSV sheet already
		local search_list : list all_vars - strings_to_output 
		local flagged_vars "`strings_to_output'"
		foreach var of local search_list {
			local lab: variable label `var'
			local var_label = lower("`lab'")
			local var_name = lower("`var'")
			foreach search_string of global final_search_list {
				local search_string = lower(`"`search_string'"')
				***Look for string in variable name:
				local name_pos = strpos("`var_name'","`search_string'")
				***Look for string in variable label: 
				local label_pos = strpos("`var_label'","`search_string'")
				if `name_pos'!=0 | `label_pos' !=0 {
					local add_to_flagged=1
					*Don't flag the variable if the variable name has any of the strings listed by the user in ignore_varname option:
					foreach ignore_string of local ignore_varname {
						local lower_ignore_string = lower("`ignore_string'")
						local ignore_name_pos = strpos("`var_name'","`lower_ignore_string'")
						if `ignore_name_pos'!=0 {
							local add_to_flagged=0
						}
					}
					if `add_to_flagged'==1 {
						display "search term `search_string' found in `var' (label = `var_label')"
						local flagged_vars "`flagged_vars' `var'"
					}
				}
			}
		}
		
		***Make sure list of flagged variables does not contain repeated variables:
		local flagged_vars : list uniq flagged_vars
		
		***Dont output variable to list if all observations are missing:
		local flagged_vars_copy `flagged_vars'
		foreach var of local flagged_vars_copy {
			capture qui assert mi(`var')
			if !_rc {
				display "`var' is missing for all observations - don't output to excel"
				local flagged_vars : list flagged_vars - var
			}
		}
				
		***Output the flagged variables to csv file: 
		foreach var of local flagged_vars {
			tempvar obsnm_temp temp2 temp3 temp4 temp5
			qui egen `temp2' = group(`var') // group var
			qui egen `temp3' = mode(`temp2'), maxmode // mode of GROUP
			qui egen `temp4' = tag(`temp2')
			qui gen `temp5' = `temp4'*`temp2' // tag*group = 1 for first obs in group 1, 0 for second obs in group 1, 2 for first obs in group 2, etc

			***First column=path
			qui putexcel A`++row' = "`file_`i''"
			***Second column=variable nam
			qui putexcel B`row' = "`var'"
			***Third column=label
			local lab: variable label `var'
			qui putexcel C`row' = "`lab'"
			***Fourth column=most frequent value  -- mode = `temp3' - value where tag*group (`temp5') = mode
			qui gen `obsnm_temp'=_n
			qui sum `obsnm_temp' if `temp3'==`temp5'
			
			***Remove quotation marks from STRING variables - quotation marks cause a problem when writing to excel
			capture confirm string variable `var'
			if _rc==0 {
				qui replace `var' = subinstr(`var',`"""',"",.)
			}
			
			local most_freq_value = `var'[`r(mean)']
			qui putexcel D`row' = "`most_freq_value'"
			***Fifth column = ratio of num diff values/num obs
			qui sum `temp2'
			***NOTE: `N' comes from "qui count" when file is first opened
			qui putexcel E`row' = "`r(max)'/`N'"
			***Sixth column = samp1 (nonmissing) --> tenth column = samp5 (nonmissing):
			***First sort by tag*group:
			*** Only do the sorting if samples>0:
			if `samples'>0 {
				gsort - `temp5'
				forvalues m=1/`samples' {
					local samp`m' = `var'[`m']
				}
				local colstartnum = 5 // first column is F (previous columns filled by other data)
				forvalues sampnum=1/`samples' {
					qui putexcel `col`++colstartnum''`row' = "`samp`sampnum''" // `col`colstartnum'' identifies a column local defined earlier in program 
				}
			}
			drop `obsnm_temp' `temp2' `temp3' `temp4' `temp5'
		}
	}
	putexcel clear
end


pii_scan ${directory_to_scan}


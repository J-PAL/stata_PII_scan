/************************************************************************************************************************************************************
Description: This file will scan all .dta files within a directory and all of its subdirectories for potential PII. Potential PII includes variables with 
names or labels containing any of the strings in global search_string. The program decodes all encoded numeric variables (i.e. those with value labels or those created 
using the command "encode") to create string variables, which are searched along with all original string variables for variables with string lengths greater than 3. 
Flagged variables are saved to pii_stata_output.csv. 

Inputs: Path to top directory.
Outputs: pii_stata_output.csv (saved to current working directory)
Date Last Modified: February 12, 2018
Last Modified By: Marisa Carlos (mcarlos@povertyactionlab.org)
************************************************************************************************************************************************************/



clear all
set more off 
set maxvar 120000

if c(username)=="mbc96_TH" {
	sysdir set PLUS "U:\Documents\Stata_personal\Downloaded"
	sysdir set PERSONAL "U:\Documents\Stata_personal\Personal"
	cd "" // CHANGE PATH TO WHERE YOU WANT TO SAVE pii_stata_output.csv
	global directory_to_scan "U:\Documents\TEST_DIR" // SET THIS DIRECTORY TO THE ONE YOU WANT TO SCAN
}

***Command "filelist" required:
capture ssc install filelist


****************************** ADD OR REMOVE SEARCH STRINGS AS NEEDED: ******************************
#delimit ;
global search_strings
	address
	bday
	beneficiary
	birth 
	census
	child
	city
	community
	compound
	coord
	country
	degree
	district
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
	precinct
	school
	second
	sex
	social
	street
	subcountry
	territory
	url
	village
	wife
;
#delimit cr
*****************************************************************************************************

capture program drop pii_scan_strings
program pii_scan_strings
	syntax anything(name=search_directory id="path of directory to search")
	
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

	qui putexcel set pii_stata_output.csv, replace
	local i=0
	foreach col in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z {
		local col`++i' "`col'"
	}
	local i=0
	local row=1
	foreach header in "file" "var" "varlabel" "most freq value" "ratio of diff values/num obs" "samp1" "samp2" "samp3" "samp4" "samp5" {
		qui putexcel `col`++i''`row' = `"`header'"'
	}
	qui count
	forvalues i=1/`r(N)' {
		display "------------------------------------------------------------------------------------------"
		display "						Searching `search_directory'/`file_`i''"
		display "------------------------------------------------------------------------------------------"
		use "`file_`i''", clear
		qui count 
		local N = r(N) // USED WHEN OUTPUTING TO CSV 
		*Initialize locals:
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
		
		*Get list of all string variables (this will include original string variables and the decoded variables) 
		foreach var of varlist * {
			capture confirm string var `var'
			if _rc==0 {
				local string_vars "`string_vars' `var'"
			}
			else {
				local numeric_vars "`numeric_vars' `var'"
			}
		}

		* Save the list of string variables that have lengths greater than 3:
		foreach var of local string_vars {
			tempvar temp1
			qui gen `temp1' = length(`var') // string length 
			qui sum `temp1'
			if `r(max)'>3 {
				local strings_to_output "`strings_to_output' `var'"
			}
		}
		
		*** Search through the rest of the variables and see if there are any of the PII search words in the variable names or labels:
		*Only look through variables that have been assigned to be output to CSV sheet already
		local search_list : list all_vars - strings_to_output 
		local flagged_vars "`strings_to_output'"
		foreach var of local search_list {
			local lab: variable label `var'
			local var_label = lower("`lab'")
			local var_name = lower("`var'")
			foreach search_string of global search_strings {
				local search_string = lower(`"`search_string'"')
				*Look for string in variable name:
				local name_pos = strpos("`var_name'","`search_string'")
				*Look for string in variable label: 
				local label_pos = strpos("`var_label'","`search_string'")
				if `name_pos'!=0 | `label_pos' !=0 {
					display "SEARCH TERM `search_string' FOUND IN VARIABLE `var_name' (label = `var_label')"
					local flagged_vars "`flagged_vars' `var'"
				}
			}
		}
		
		*** Output the flagged variables to csv file: 
		foreach var of local flagged_vars {
			tempvar obsnm_temp temp2 temp3 temp4 temp5
			qui egen `temp2' = group(`var') // group var
			qui egen `temp3' = mode(`temp2'), maxmode // mode of GROUP
			qui egen `temp4' = tag(`temp2')
			qui gen `temp5' = `temp4'*`temp2' // tag*group = 1 for first obs in group 1, 0 for second obs in group 1, 2 for first obs in group 2, etc

			*First column=path
			qui putexcel A`++row' = "`file_`i''"
			*Second column=variable nam
			qui putexcel B`row' = "`var'"
			*Third column=label
			local lab: variable label `var'
			qui putexcel C`row' = "`lab'"
			*Fourth column=most frequent value  -- mode = `temp3' - value where tag*group (`temp5') = mode
			qui gen `obsnm_temp'=_n
			qui sum `obsnm_temp' if `temp3'==`temp5'
			local most_freq_value = `var'[`r(mean)']
			qui putexcel D`row' = "`most_freq_value'"
			*Fifth column = ratio of num diff values/num obs
			qui sum `temp2'
			*NOTE: `N' comes from "qui count" when file is first opened
			qui putexcel E`row' = "`r(max)'/`N'"
			*Sixth column = samp1 (nonmissing) --> tenth column = samp5 (nonmissing):
			*First sort by tag*group:
			gsort - `temp5'
			forvalues m=1/5 {
				local samp`m' = `var'[`m']
			}
			local num=0
			foreach column in "F" "G" "H" "I" "J" {
				qui putexcel `column'`row' = "`samp`++num''"
			}
			
			drop `obsnm_temp' `temp2' `temp3' `temp4' `temp5'
		}
	}
	putexcel clear
end
pii_scan_strings ${directory_to_scan}

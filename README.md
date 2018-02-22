# stata_PII_scan
Stata program to scan for personally identifiable information (PII)

## Description

This do-file will scan all .dta files within a directory and all of its subdirectories for potential PII. A list of potential PII is saved to pii_stata_output.xlsx.

Potential PII includes the following: 
- Variables with names or labels containing any of the strings in the search strings list (see below)
- String variables with lengths greater than 3 (or the user-defined value)
- Encoded variables (i.e. those with value labels or those created with the "encode" command) where the value labels have lengths greater than 3

## Search Strings 

	*address
	*bday
	*beneficiary
	*birth 
	*census
	*child
	*city
	*community
	*compound
	*coord
	*country
	*degree
	*district
	*dob
	*daughter
	*email
	*father
	*fax
	*gender
	*gps
	*house
	*husband
	*lat
	*loc 
	*location
	*lon
	*minute
	*mother
	*municipality
	*name
	*network
	*panchayat
	*parish
	*precinct
	*school
	*second
	*sex
	*social
	*son
	*street
	*subcountry
	*territory
	*url
	*village
	*wife
	*zip

## Instructions

#### Syntax

pii_scan "path of directory to scan" [, *options*]

#### Options:
	*remove_search_list(string) : remove strings from the search list 
	*add_search_list(string) : add strings to the search list 
	*ignore_varname(string) : do not flag variables with any of these strings in the variable name
	*string_length(#) : length of string variables to flag (default is 3)
	*samples(#) : number of samples to write to output file (default is 5) 

#### Example: 

pii_scan "C:/Documents/PII_Scan", remove_search_list(lat lon zip) add_search_list(q15) ignore_varname(Not_PII_Name) string_length(5) samples(integer 10)

## Requirements

Stata command "filelist" (running entire do-file will install it automatically)

## Support

Please use the [issue tracker](https://github.com/J-PAL/PII-Scan/issues) for all support requests.

## License

See [license file](LICENSE.txt).

## Thanks
Special thanks to IPA for their [How to Search Datasets for Personally Identifiable Information](http://www.poverty-action.org/sites/default/files/Guideline_How-to-Search-Datasets-for-PII.pdf) document which inspired this project.
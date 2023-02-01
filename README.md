# stata_PII_scan
Stata program to scan for personally identifiable information (PII)

## Description

This file will scan all .dta files within a directory and all of its subdirectories for potential PII. A list of potential PII is saved to pii_stata_output.xlsx.

Potential PII includes the following: 
- Variables with names or labels containing any of the strings in the search strings list (see below)
- String variables with lengths greater than 3 (or the user-defined value)(excluding binary variables w/ >2 non-missing responses)
- Encoded variables (i.e. those with value labels or those created with the "encode" command) where the value labels have lengths greater than 3 (exlcuding those w/ <= 10 categories)

Note the .ado file can be used in place of the .do file if the user prefers. 

## Search Strings 
address, bday, beneficiary, birth, block, census, child, city, community, compound, coord, country, degree, district, dob, daughter, email, father, fax, gender, gps, house, husband, lat, loc, location, lon, minute, mother, municipality, name, network, panchayat, parish, phone, precinct, school, second, sex, social, son, spouse, street, subcountry, territory, url, village, wife, zip

## Instructions

### Syntax

pii_scan "path of directory to scan" [, *options*]

### Options:
* **remove_search_list(string)**: remove strings from the search list
* **add_search_list(string)**: add strings to the search list 
* **ignore_varname(string)**: do not flag variables with any of these strings in the variable name
* **string_length(#)**: length of string variables to flag (default is 3)
* **samples(#)**: number of samples to write to output file (default is 5) 

### Example: 

pii_scan "C:/Documents/PII_Scan", remove_search_list(lat lon zip) add_search_list(q15) ignore_varname(Not_PII_Name) string_length(5) samples(10)
* **remove_search_list(lat lon zip)** removes lat, lon, and zip from list of strings to search for 
* **add_search_list(q15)** adds q15 to list of strings to search for 
* **ignore_varname(Not_PII_Name)** tells the program not to flag any variables with the string "Not_PII_Name" in the variable name (not sensitive to case)
* **string_length(5)** flags string variables with lengths greater than 5
* **samples(10)** writes 10 samples of the data to the output file instead of the default 5

## Output 
The program saves *pii_stata_output.xlsx* to the working directory. The columns of this worksheet are: 
* **file**: Path of the .dta file (excluding the directory to scan); if the variable is in multiple files then all are listed
* **var**: Variable name
* **varlabel**: Variable label
* **most freq value**: Most frequent value of the variable in the data
* **uniquevalues**: Number of unique values of the variable in the data
* **totalobs**: Number of observations of the variable
* **firstreasonflagged**: The first reason why the variable was flagged as potential PII
* **samp1 - sampN**: Samp1 is the first unique, non-missing value the variable takes, samp2 is the second, and so on. This is also useful for manually inspecting the output for true PII.
* **Multiple_datasets**: Whether the variable is found in multiple datasets in the directory (based on variable name and label).

## Requirements

Stata command "filelist" (running entire do-file will install it automatically)

## Support

Please use the [issue tracker](https://github.com/mbcarlos96/stata_PII_scan/issues) for all support requests.

## License

See [license file](LICENSE).

## Thanks
Special thanks to IPA for their [How to Search Datasets for Personally Identifiable Information](http://www.poverty-action.org/sites/default/files/Guideline_How-to-Search-Datasets-for-PII.pdf) document which inspired this project.

clear all

/*********************
ISTAT_MFR_HBS_2023
  |-- import.do
  |-- METADATI \
  |   |-- ...
  |   |-- ISTAT_MFR_HBS_Tracciato_2023_DELIMITED.html
  |   |-- ...
  |   +-- Classificazioni \
  |       |-- ISTAT_MFR_HBS_Classificazione_2023_var1.html
  |       |-- ...
  |       +-- ISTAT_MFR_HBS_Classificazione_2023_var99.html
  +-- MICRODATI \
      +-- ISTAT_MFR_HBS_Microdati_2023_DELIMITED.txt

ssc inst htmltab2stata
****************************/

local input1 ISTAT_MFR_HBS_Tracciato_2023_DELIMITED.html
local input2 ISTAT_MFR_HBS_Microdati_2023_DELIMITED.txt
local output1 HBS2023.dta

frame change default
import delimited "METADATI/`input1'", delimiter("|||") clear encoding(UTF-8)
keep if strmatch(v1,"<tr *")
replace v1=subinstr(v1,"&nbsp;","",.) /*celle vuote*/
replace v1=subinstr(v1,"</tr>","",.) /*fine riga*/
replace v1=subinstr(v1,"<tr ","",.) /*inizio riga*/

replace v1=subinstr(v1,"</td><td>","|||",.)
replace v1=subinstr(v1,"><td>","|||",.)
split v1, gen(var) parse("|||")
drop in 1
drop v1

replace var5=lower(var5) /* --> vars name */

replace var6=regexs(1) if regexm(var6, `"<a href="./(.*)">"') /* --> link per label define categoriche */
replace var6="" if var6=="-"

replace var11=regexs(1) if regexm(var11, `""(.*)""') & strmatch(var11,`""*"') /* --> label var */
replace var11=subinstr(var11,`"""',"",.)
replace var11=subinstr(var11,`"u'"',"ù",.)
replace var11=subinstr(var11,`"a'"',"à",.)
replace var11=subinstr(var11,`"o'"',"ò",.)
replace var11=subinstr(var11,`"i'"',"ì",.)
replace var11=subinstr(lower(var11),`"e'"',"è",.)

list var11 if strmatch(var11, "spesa per *")
replace var11=subinstr(var11, "spesa per ","",1)

replace var11=subinstr(var11,"Spesa per c","C",1)
replace var11=subinstr(var11," (tovaglioli, piatti e bicchieri di plastica o carta, pellicola, carta forno, ecc.)","",1)
replace var11=subinstr(var11," (in grani, macinato, in cialde)","",1)
replace var11=subinstr(var11," (saponi, deodoranti, fazzoletti di carta, pannolini per bambini, ecc.)","",1)
forvalues c=12(-1)1 {
  replace var11=subinstr(var11," del componente `c'","",1)
}
replace var11=trim(var11)
format var11 %-205s
list var11 if strlen(var11)>80, sep(0) noobs /* up to 80 characters*/

gen labelvar = "label var " + lower(var5) + `" ""' + lower(var11) + `"""'
drop var12 var13 var14 var15 var16

gen labdefcomm = ""
qui count
local NVAR = `r(N)'
forvalues r=1(1)`NVAR' {
  if var6[`r'] != "" {
    local VAR =  lower(var5) in `r'
    local link = var6 in `r'
    di "`link'"
    preserve
      htmltab2stata, url(METADATI/`link')
      list, sep(0) noobs

      drop in 1
      local labdefine = "label define `VAR' "
      replace myvar2 = subinstr(myvar2,`"""',"'",.  )
      replace myvar2=subinstr(myvar2,"gi�","già",.)
      replace myvar2=subinstr(myvar2,"s�","sì",.)
      replace myvar2=subinstr(myvar2,"S�","Sì",.)
      replace myvar2=subinstr(myvar2,"pu�","può",.)
      replace myvar2=subinstr(myvar2,"pi�","più",.)
      replace myvar2=subinstr(myvar2," � "," è ",.)
      replace myvar2=subinstr(myvar2,"� importante","É importante",.)
      replace myvar2=subinstr(myvar2,"dall�assicurazione","dall'assicurazione",.)
      replace myvar2=subinstr(myvar2,"propriet�","proprietà",.)
      replace myvar2=subinstr(myvar2,"difficolt�","difficoltà",.)
      replace myvar2=subinstr(myvar2,"piu� volte","più volte",.)
      replace myvar2=subinstr(myvar2,"l�anno","l'anno",.)
      replace myvar2=subinstr(myvar2,"migliorer�","migliorerà",.)
      replace myvar2=subinstr(myvar2,"rester�","resterà",.)
      replace myvar2=subinstr(myvar2,"peggiorer�","peggiorerà",.)
      qui count
      forvalues n=1(1)`r(N)' {
        local VAL = myvar1 in `n'
        if inlist("`VAL'",".","") local VAL = ".a"
        local VALDESC = myvar2  in `n'
        local labdefine = `"`labdefine' `VAL' "`VALDESC'" "'
      }
      di `"`labdefine'"'
    restore
    replace labdefcomm = `"`labdefine'"' in `r'
  }
}

keep labelvar labdefcomm
frame copy default labels_frame, replace

import delimited "MICRODATI/`input2'", clear delim("^")
local cnt = 1
foreach V of varlist * {
  frame labels_frame: local labelvarcommand = labelvar in `cnt'
  `labelvarcommand'
  frame labels_frame: local labeldefinecommand = labdefcomm in `cnt'
  if `"`labeldefinecommand'"' != "" {
    destring `V', replace
    `labeldefinecommand'
    label values `V' `V'
  }
  local cnt = `++cnt'
}

compress
save `output1', replace

exit


